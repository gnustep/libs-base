/* Implementation of class NSLengthFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.

   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Tue Oct  8 13:30:33 EDT 2019

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
#import "Foundation/NSLengthFormatter.h"
#import "Foundation/NSMeasurement.h"
#import "Foundation/NSMeasurementFormatter.h"
#import "Foundation/NSNumberFormatter.h"
#import "Foundation/NSUnit.h"

@implementation NSLengthFormatter

- (instancetype) init
{
  self = [super init];
  if(self != nil)
    {
      _numberFormatter = nil;
      _unitStyle = NSFormattingUnitStyleMedium;
      _isForPersonHeightUse = NO;
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

- (BOOL) isForPersonHeightUse
{
  return _isForPersonHeightUse;
}

- (void) setForPersonHeightUse: (BOOL)flag
{
  _isForPersonHeightUse = flag;
}

- (NSString *) stringFromValue: (double)value unit: (NSLengthFormatterUnit)unit
{
  NSUnit *u = nil;
  NSMeasurement *m = nil;
  NSMeasurementFormatter *mf = nil;

  switch(unit)
    {
    case NSLengthFormatterUnitMillimeter:
      u = [NSUnitLength millimeters];
      break;
    case NSLengthFormatterUnitCentimeter:
      u = [NSUnitLength centimeters];
      break;
    case NSLengthFormatterUnitMeter:
      u = [NSUnitLength meters];
      break;
    case NSLengthFormatterUnitKilometer:
      u = [NSUnitLength kilometers];
      break;
    case NSLengthFormatterUnitInch:
      u = [NSUnitLength inches];
      break;
    case NSLengthFormatterUnitFoot:
      u = [NSUnitLength feet];
      break;
    case NSLengthFormatterUnitYard:
      u = [NSUnitLength yards];
      break;
    case NSLengthFormatterUnitMile:
      u = [NSUnitLength miles];
      break;
    }

  m = [[NSMeasurement alloc] initWithDoubleValue: value
					    unit: u];
  AUTORELEASE(m);
  mf = [[NSMeasurementFormatter alloc] init];
  AUTORELEASE(mf);
  [mf setUnitStyle: _unitStyle];
  [mf setNumberFormatter: [self numberFormatter]];

  return [mf stringFromMeasurement: m];
}

- (NSString *) stringFromMeters: (double)numberInMeters
{
  return [self stringFromValue: numberInMeters unit: NSLengthFormatterUnitMeter];
}

- (NSString *) unitStringFromValue: (double)value unit: (NSLengthFormatterUnit)unit
{
  return [self stringFromValue: value unit: unit];
}

- (NSString *) unitStringFromMeters: (double)numberInMeters usedUnit: (NSLengthFormatterUnit *)unit
{
  NSLengthFormatterUnit usedUnit = NSLengthFormatterUnitMeter;
  if (unit != NULL)
    {
      *unit = usedUnit;
    }
  return [self stringFromValue: numberInMeters unit: usedUnit];
}

- (NSString *) stringForObjectValue: (id)obj
{
  double meters = 0.0;

  if ([obj respondsToSelector: @selector(doubleValue)])
    {
      meters = [obj doubleValue];
    }

  return [self stringFromMeters: meters];
}

- (BOOL) getObjectValue: (id *)obj forString: (NSString *)string errorDescription: (NSString **)error
{
  return NO;
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          _isForPersonHeightUse = [coder decodeBoolForKey: @"NS.forPersonHeightUse"];
          ASSIGN(_numberFormatter, [coder decodeObjectForKey: @"NS.numberFormatter"]);
          _unitStyle = [coder decodeIntegerForKey: @"NS.unitStyle"];
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(BOOL) at: &_isForPersonHeightUse];
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
      [coder encodeBool: _isForPersonHeightUse forKey: @"NS.forPersonHeightUse"];
      [coder encodeObject: _numberFormatter forKey: @"NS.numberFormatter"];
      [coder encodeInteger: _unitStyle forKey: @"NS.unitStyle"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(BOOL) at: &_isForPersonHeightUse];
      [coder encodeValueOfObjCType: @encode(id) at: &_numberFormatter];
      [coder encodeValueOfObjCType: @encode(NSFormattingUnitStyle) at: &_unitStyle];
    }
}

@end
