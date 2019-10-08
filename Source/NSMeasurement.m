
/* Implementation of class NSMeasurement
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
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

@implementation NSMeasurement
// Creating Measurements
- (instancetype)initWithDoubleValue: (double)doubleValue 
                               unit: (NSUnit *)unit
{
  return nil;
}

// Accessing unit and value
- (NSUnit *) unit
{
  return nil;
}

- (double) doubleValue
{
}

// Conversion
- (BOOL) canBeConvertedToUnit: (NSUnit *)unit
{
  return NO;
}

- (NSMeasurement *)measurementByConvertingToUnit:(NSUnit *)unit
{
  return nil;
}

// Operating
- (NSMeasurement *)measurementByAddingMeasurement:(NSMeasurement *)measurement
{
  return nil;
}

- (NSMeasurement *)measurementBySubtractingMeasurement:(NSMeasurement *)measurement
{
  return nil;
}
@end

