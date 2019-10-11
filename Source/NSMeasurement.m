
/* Implementation of class NSMeasurement
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Mon Sep 30 15:58:21 EDT 2019

   This file is part of the GNUstep Library.
   
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

#include <Foundation/NSMeasurement.h>
#include <Foundation/NSUnit.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSKeyedArchiver.h>

@implementation NSMeasurement
// Creating Measurements
- (instancetype)initWithDoubleValue: (double)doubleValue 
                               unit: (NSUnit *)unit
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_unit, unit);
      _doubleValue = doubleValue;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_unit);
  [super dealloc];
}

// Accessing unit and value
- (NSUnit *) unit
{
  return _unit;
}

- (double) doubleValue
{
  return _doubleValue;
}

// Conversion
- (BOOL) canBeConvertedToUnit: (NSUnit *)unit
{
  return ([unit isKindOfClass: [_unit class]] &&
          [unit respondsToSelector: @selector(converter)]);
}

- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit
{
  NSMeasurement *result = nil;
  double val = 0.0;
  if([self canBeConvertedToUnit: unit])
    {
      // Do conversion...
      NSUnitConverter *c = [(NSDimension *)unit converter];
      val = [c baseUnitValueFromValue: _doubleValue];
      result = [[NSMeasurement alloc] initWithDoubleValue: val unit: unit];
      AUTORELEASE(result);
    }
  else
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Cannot convert from %@ to %@", _unit, unit];
    }
  return result;
}

// Operating
- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)measurement
{
  NSMeasurement *newMeasurement = [measurement measurementByConvertingToUnit: _unit];
  NSMeasurement *result = nil;
  double v = 0.0;

  v = _doubleValue + [newMeasurement doubleValue];
  result = [[NSMeasurement alloc] initWithDoubleValue: v unit: _unit];
  AUTORELEASE(result);
  
  return result;
}

- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)measurement
{
  NSMeasurement *newMeasurement = [measurement measurementByConvertingToUnit: _unit];
  NSMeasurement *result = nil;
  double v = 0.0;

  v = _doubleValue - [newMeasurement doubleValue];
  result = [[NSMeasurement alloc] initWithDoubleValue: v unit: _unit];
  AUTORELEASE(result);
  
  return result;
}

// NSCopying
- (id) copyWithZone: (NSZone *)zone
{
  return [[[self class] allocWithZone: zone] initWithDoubleValue: _doubleValue
                                                            unit: _unit];
}

// NSCoding
- (void) encodeWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      [coder encodeObject: _unit forKey: @"unit"];
      [coder encodeDouble: _doubleValue forKey: @"doubleValue"];
    }
  else
    {
      [coder encodeObject: _unit];
      [coder encodeValueOfObjCType: @encode(double) at: &_doubleValue];
    }
}

- (id) initWithCoder: (NSCoder *)coder
{
  if((self = [super init]) != nil)
    {
      if([coder allowsKeyedCoding])
        {
          _unit = [coder decodeObjectForKey: @"unit"];
          _doubleValue = [coder decodeDoubleForKey: @"doubleValue"];
        }
      else
        {
          _unit = [coder decodeObject];
          [coder decodeValueOfObjCType: @encode(double) at: &_doubleValue];
        }
    }
  return self;
}
@end

