/* Definition of class NSNumberFormatter
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Fred Kiefer <FredKiefer@gmx.de>
   Date: 	July 2000
   Updated by: Richard Frith-Macdonald <rfm@gnu.org> Sept 2001
   
   This file is part of the GNUstep Library.
   
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

#ifndef _NSNumberFormatter_h__
#define _NSNumberFormatter_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSFormatter.h>
#include <Foundation/NSDecimalNumber.h>

@class	NSString, NSAttributedString, NSDictionary;

@interface NSNumberFormatter: NSFormatter
{
  BOOL _hasThousandSeparators;
  BOOL _allowsFloats;
  BOOL _localizesFormat;
  unichar _thousandSeparator;
  unichar _decimalSeparator;
  NSDecimalNumberHandler *_roundingBehavior;
  NSDecimalNumber *_maximum;
  NSDecimalNumber *_minimum;
  NSAttributedString *_attributedStringForNil;
  NSAttributedString *_attributedStringForNotANumber;
  NSAttributedString *_attributedStringForZero;
  NSString *_negativeFormat;
  NSString *_positiveFormat;
  NSDictionary *_attributesForPositiveValues;
  NSDictionary *_attributesForNegativeValues;
}

// Format
- (NSString*) format;
- (void) setFormat: (NSString*)aFormat;
- (BOOL) localizesFormat;
- (void) setLocalizesFormat: (BOOL)flag;
- (NSString*) negativeFormat;
- (void) setNegativeFormat: (NSString*)aFormat;
- (NSString*) positiveFormat;
- (void) setPositiveFormat: (NSString*)aFormat;

// Attributed Strings
- (NSAttributedString*) attributedStringForNil;
- (void) setAttributedStringForNil: (NSAttributedString*)newAttributedString;
- (NSAttributedString*) attributedStringForNotANumber;
- (void) setAttributedStringForNotANumber: (NSAttributedString*)newAttributedString;
- (NSAttributedString*) attributedStringForZero;
- (void) setAttributedStringForZero: (NSAttributedString*)newAttributedString;
- (NSDictionary*) textAttributesForNegativeValues;
- (void) setTextAttributesForNegativeValues: (NSDictionary*)newAttributes;
- (NSDictionary*) textAttributesForPositiveValues;
- (void) setTextAttributesForPositiveValues: (NSDictionary*)newAttributes;

// Rounding
- (NSDecimalNumberHandler*) roundingBehavior;
- (void) setRoundingBehavior: (NSDecimalNumberHandler*)newRoundingBehavior;

// Separators
- (BOOL) hasThousandSeparators;
- (void) setHasThousandSeparators: (BOOL)flag;
- (NSString*) thousandSeparator;
- (void) setThousandSeparator: (NSString*)newSeparator;
- (BOOL) allowsFloats;
- (void) setAllowsFloats: (BOOL)flag;
- (NSString*) decimalSeparator;
- (void) setDecimalSeparator: (NSString*)newSeparator;

// Maximum/minimum
- (NSDecimalNumber*) maximum;
- (void) setMaximum: (NSDecimalNumber*)aMaximum;
- (NSDecimalNumber*) minimum;
- (void) setMinimum: (NSDecimalNumber*)aMinimum;

@end

#endif
