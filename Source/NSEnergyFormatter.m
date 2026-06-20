/** Implementation of class NSEnergyFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.

   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Tue Oct  8 13:30:10 EDT 2019

   This file is part of the GNUstep Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "Foundation/NSArchiver.h"
#import "Foundation/NSKeyedArchiver.h"
#import "Foundation/NSEnergyFormatter.h"
#import "Foundation/NSMeasurement.h"
#import "Foundation/NSMeasurementFormatter.h"
#import "Foundation/NSNumberFormatter.h"
#import "Foundation/NSUnit.h"

// Short and medium style unit strings
#define UNIT_JOULE_SHORT @"J"
#define UNIT_KILOJOULE_SHORT @"kJ"
#define UNIT_CALORIE_SHORT @"cal"
#define UNIT_KILOCALORIE_SHORT @"kcal"
#define UNIT_CALORIE_FOOD_SHORT @"Cal"

// Long style unit strings - singular
#define UNIT_JOULE_LONG_SINGULAR @"joule"
#define UNIT_KILOJOULE_LONG_SINGULAR @"kilojoule"
#define UNIT_CALORIE_LONG_SINGULAR @"calorie"
#define UNIT_KILOCALORIE_LONG_SINGULAR @"kilocalorie"
#define UNIT_CALORIE_FOOD_LONG_SINGULAR @"Calorie"

// Long style unit strings - plural
#define UNIT_JOULE_LONG_PLURAL @"joules"
#define UNIT_KILOJOULE_LONG_PLURAL @"kilojoules"
#define UNIT_CALORIE_LONG_PLURAL @"calories"
#define UNIT_KILOCALORIE_LONG_PLURAL @"kilocalories"
#define UNIT_CALORIE_FOOD_LONG_PLURAL @"Calories"

@implementation NSEnergyFormatter

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _numberFormatter = nil;
      _unitStyle = NSFormattingUnitStyleMedium;
      _isForFoodEnergyUse = NO;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_numberFormatter);
  [super dealloc];
}

- (NSNumberFormatter *) numberFormatter
{
  if (_numberFormatter == nil)
    {
      NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
      [fmt setNumberStyle: NSNumberFormatterDecimalStyle];
      ASSIGN(_numberFormatter, fmt);
      RELEASE(fmt);
    }
  return _numberFormatter;
}

- (void) setNumberFormatter: (NSNumberFormatter *)formatter
{
  ASSIGN(_numberFormatter, formatter);
}

- (NSFormattingUnitStyle) unitStyle
{
  return _unitStyle;
}

- (void) setUnitStyle: (NSFormattingUnitStyle)style
{
  _unitStyle = style;
}

- (BOOL) isForFoodEnergyUse
{
  return _isForFoodEnergyUse;
}

- (void) setForFoodEnergyUse: (BOOL)flag
{
  _isForFoodEnergyUse = flag;
}

- (NSString *) stringFromValue: (double)value unit: (NSEnergyFormatterUnit)unit
{
  NSString *formattedNumber = nil;
  NSString *unitString = nil;
  NSString *result = nil;

  // Format the numeric value
  formattedNumber = [[self numberFormatter] stringFromNumber: [NSNumber numberWithDouble: value]];

  // Determine unit string based on style and unit
  switch (_unitStyle)
    {
    case NSFormattingUnitStyleShort:
      switch (unit)
	{
	case NSEnergyFormatterUnitJoule:
	  unitString = UNIT_JOULE_SHORT;
	  break;
	case NSEnergyFormatterUnitKilojoule:
	  unitString = UNIT_KILOJOULE_SHORT;
	  break;
	case NSEnergyFormatterUnitCalorie:
	  unitString = UNIT_CALORIE_SHORT;
	  break;
	case NSEnergyFormatterUnitKilocalorie:
	  unitString = (_isForFoodEnergyUse) ? UNIT_CALORIE_FOOD_SHORT : UNIT_KILOCALORIE_SHORT;
	  break;
	}
      result = [NSString stringWithFormat: @"%@%@", formattedNumber, unitString];
      break;

    case NSFormattingUnitStyleMedium:
      switch (unit)
	{
	case NSEnergyFormatterUnitJoule:
	  unitString = UNIT_JOULE_SHORT;
	  break;
	case NSEnergyFormatterUnitKilojoule:
	  unitString = UNIT_KILOJOULE_SHORT;
	  break;
	case NSEnergyFormatterUnitCalorie:
	  unitString = UNIT_CALORIE_SHORT;
	  break;
	case NSEnergyFormatterUnitKilocalorie:
	  unitString = (_isForFoodEnergyUse) ? UNIT_CALORIE_FOOD_SHORT : UNIT_KILOCALORIE_SHORT;
	  break;
	}
      result = [NSString stringWithFormat: @"%@ %@", formattedNumber, unitString];
      break;

    case NSFormattingUnitStyleLong:
      switch (unit)
	{
	case NSEnergyFormatterUnitJoule:
	  unitString = (value == 1.0) ? UNIT_JOULE_LONG_SINGULAR : UNIT_JOULE_LONG_PLURAL;
	  break;
	case NSEnergyFormatterUnitKilojoule:
	  unitString = (value == 1.0) ? UNIT_KILOJOULE_LONG_SINGULAR : UNIT_KILOJOULE_LONG_PLURAL;
	  break;
	case NSEnergyFormatterUnitCalorie:
	  if (_isForFoodEnergyUse)
	    unitString = (value == 1.0) ? UNIT_CALORIE_FOOD_LONG_SINGULAR : UNIT_CALORIE_FOOD_LONG_PLURAL;
	  else
	    unitString = (value == 1.0) ? UNIT_CALORIE_LONG_SINGULAR : UNIT_CALORIE_LONG_PLURAL;
	  break;
	case NSEnergyFormatterUnitKilocalorie:
	  if (_isForFoodEnergyUse)
	    unitString = (value == 1.0) ? UNIT_CALORIE_FOOD_LONG_SINGULAR : UNIT_CALORIE_FOOD_LONG_PLURAL;
	  else
	    unitString = (value == 1.0) ? UNIT_KILOCALORIE_LONG_SINGULAR : UNIT_KILOCALORIE_LONG_PLURAL;
	  break;
	}
      result = [NSString stringWithFormat: @"%@ %@", formattedNumber, unitString];
      break;

    default:
      // Fallback to NSMeasurementFormatter for unknown styles
      {
	NSUnit *u = nil;
	NSMeasurement *m = nil;
	NSMeasurementFormatter *mf = nil;

	switch (unit)
	  {
	  case NSEnergyFormatterUnitJoule:
	    u = [NSUnitEnergy joules];
	    break;
	  case NSEnergyFormatterUnitKilojoule:
	    u = [NSUnitEnergy kilojoules];
	    break;
	  case NSEnergyFormatterUnitCalorie:
	    u = [NSUnitEnergy calories];
	    break;
	  case NSEnergyFormatterUnitKilocalorie:
	    u = [NSUnitEnergy kilocalories];
	    break;
	  }

	m = [[NSMeasurement alloc] initWithDoubleValue: value
						  unit: u];
	AUTORELEASE(m);
	mf = [[NSMeasurementFormatter alloc] init];
	AUTORELEASE(mf);
	[mf setUnitStyle: _unitStyle];
	[mf setNumberFormatter: [self numberFormatter]];

	result = [mf stringFromMeasurement: m];
      }
      break;
    }

  return result;
}

- (NSString *) stringFromJoules: (double)numberInJoules
{
  return [self stringFromValue: numberInJoules unit: NSEnergyFormatterUnitJoule];
}

- (NSString *) unitStringFromValue: (double)value unit: (NSEnergyFormatterUnit)unit
{
  return [self stringFromValue: value unit: unit];
}

- (NSString *) unitStringFromJoules: (double)numberInJoules usedUnit: (NSEnergyFormatterUnit *)unit
{
  NSEnergyFormatterUnit usedUnit = NSEnergyFormatterUnitJoule;
  if (unit != NULL)
    {
      *unit = usedUnit;
    }
  return [self stringFromValue: numberInJoules unit: usedUnit];
}

- (NSString *) stringForObjectValue: (id)obj
{
  double joules = 0.0;

  if ([obj respondsToSelector: @selector(doubleValue)])
    {
      joules = [obj doubleValue];
    }

  return [self stringFromJoules: joules];
}

- (BOOL) getObjectValue: (id *)obj forString: (NSString *)string errorDescription: (NSString **)error
{
  if (error != NULL)
    {
      *error = @"Parsing not implemented";
    }
  return NO;
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
	{
	  _isForFoodEnergyUse = [coder decodeBoolForKey: @"NS.forFoodEnergyUse"];
	  ASSIGN(_numberFormatter, [coder decodeObjectForKey: @"NS.numberFormatter"]);
	  _unitStyle = [coder decodeIntegerForKey: @"NS.unitOptions"];
	}
      else
	{
	  [coder decodeValueOfObjCType: @encode(BOOL) at: &_isForFoodEnergyUse];
	  [coder decodeValueOfObjCType: @encode(id) at: &_numberFormatter];
	  [coder decodeValueOfObjCType: @encode(NSFormattingUnitStyle) at: &_unitStyle];
	}
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeBool: _isForFoodEnergyUse forKey: @"NS.forFoodEnergyUse"];
      [coder encodeObject: _numberFormatter forKey: @"NS.numberFormatter"];
      [coder encodeInteger: _unitStyle forKey: @"NS.unitOptions"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(BOOL) at: &_isForFoodEnergyUse];
      [coder encodeValueOfObjCType: @encode(id) at: &_numberFormatter];
      [coder encodeValueOfObjCType: @encode(NSFormattingUnitStyle) at: &_unitStyle];
    }
}

@end
