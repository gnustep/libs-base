/* 
   NSNumberFormatter class
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Created: July 2000

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

#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAttributedString.h>
#include <Foundation/NSDecimalNumber.h>
#include <Foundation/NSNumberFormatter.h>


@implementation NSNumberFormatter

+ (void) initialize
{
}

- (id) init
{
  _allowsFloats = YES;
  [self setAttributedStringForNil: AUTORELEASE([[NSAttributedString new] 
						   initWithString: @""])];
  [self setAttributedStringForNotANumber: AUTORELEASE([[NSAttributedString new] 
						   initWithString: @"NaN"])];

  return self;
}

// Coding
- (void)encodeWithCoder:(NSCoder *)encoder
{
}

- (id)initWithCoder:(NSCoder *)decoder
{
  return self;
}

// Copying
- (id)copyWithZone:(NSZone *)zone
{
  return NSCopyObject(self, 0, zone);
}

// NSFormatter
- (NSAttributedString*) attributedStringForObjectValue: (id)anObject
				 withDefaultAttributes: (NSDictionary*)attr
{
  // FIXME
  return AUTORELEASE([[NSAttributedString alloc] initWithString: 
						     [self editingStringForObjectValue: anObject]
						 attributes: attr]);  
}

- (NSString*) editingStringForObjectValue: (id)anObject
{
  return [self stringForObjectValue: anObject];
}

- (BOOL) getObjectValue: (id*)anObject
	      forString: (NSString*)string
       errorDescription: (NSString**)error
{
  return NO;
}

- (BOOL) isPartialStringValid: (NSString*)partialString
	     newEditingString: (NSString**)newString
	     errorDescription: (NSString**)error
{
  if (newString != NULL)
    *newString = partialString;

  return YES;
}

- (NSString*) stringForObjectValue: (id)anObject
{
  if (nil == anObject)
    return [[self attributedStringForNil] string];

  return [anObject description];
}

// Format
- (BOOL)localizesFormat
{
  return _localizesFormat;
}

- (void)setLocalizesFormat:(BOOL)flag
{
  _localizesFormat = flag;
}

- (NSString *)format
{
  return nil;
}

- (void)setFormat:(NSString *)aFormat
{

}

- (NSString *)negativeFormat
{
  return nil;
}

- (void)setNegativeFormat:(NSString *)aFormat
{
}

- (NSString *)positiveFormat
{
  return nil;
}

- (void)setPositiveFormat:(NSString *)aFormat
{
}

// Attributed Strings
- (NSAttributedString *)attributedStringForNil
{
  return _attributedStringForNil;
}

- (void)setAttributedStringForNil:(NSAttributedString *)newAttributedString
{
  if (nil == newAttributedString)
    {
      RELEASE(_attributedStringForNil);
      _attributedStringForNil = nil; 
    }
  else
    ASSIGN(_attributedStringForNil, newAttributedString);
}

- (NSAttributedString *)attributedStringForNotANumber
{
  return _attributedStringForNotANumber;
}

- (void)setAttributedStringForNotANumber:(NSAttributedString *)newAttributedString
{
  ASSIGN(_attributedStringForNotANumber, newAttributedString);
}

- (NSAttributedString *)attributedStringForZero
{
  return _attributedStringForZero;
}

- (void)setAttributedStringForZero:(NSAttributedString *)newAttributedString
{
  ASSIGN(_attributedStringForZero, newAttributedString);
}

- (NSDictionary *)textAttributesForNegativeValues
{
  return nil;
}

- (void)setTextAttributesForNegativeValues:(NSDictionary *)newAttributes
{
}

- (NSDictionary *)textAttributesForPositiveValues
{
    return nil;
}

- (void)setTextAttributesForPositiveValues:(NSDictionary *)newAttributes
{
}

// Rounding
- (NSDecimalNumberHandler *)roundingBehavior
{
  return _roundingBehavior;
}

- (void)setRoundingBehavior:(NSDecimalNumberHandler *)newRoundingBehavior
{
  ASSIGN(_roundingBehavior, newRoundingBehavior);
}

// Separators
- (BOOL)hasThousandSeparators
{
  return _hasThousandSeparators;
}

- (void)setHasThousandSeparators:(BOOL)flag
{
  _hasThousandSeparators = flag;
}

- (NSString *)thousandSeparator
{
  return _thousandSeparator;
}

- (void)setThousandSeparator:(NSString *)newSeparator
{
  ASSIGN(_thousandSeparator, newSeparator);
}

- (BOOL)allowsFloats
{
  return _allowsFloats;
}

- (void)setAllowsFloats:(BOOL)flag
{
  _allowsFloats = flag;
}

- (NSString *)decimalSeparator
{
  return _decimalSeparator;
}

- (void)setDecimalSeparator:(NSString *)newSeparator
{
  ASSIGN(_decimalSeparator, newSeparator);
}

// Maximum/minimum
- (NSDecimalNumber *)maximum
{
  return _maximum;
}

- (void)setMaximum:(NSDecimalNumber *)aMaximum
{
  ASSIGN(_maximum, aMaximum);
}

- (NSDecimalNumber *)minimum
{
  return _minimum;  
}

- (void)setMinimum:(NSDecimalNumber *)aMinimum
{
    ASSIGN(_minimum, aMinimum);
}
