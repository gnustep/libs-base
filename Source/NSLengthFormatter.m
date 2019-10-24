
/* Implementation of class NSLengthFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Tue Oct  8 13:30:33 EDT 2019

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

#include <Foundation/NSLengthFormatter.h>

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

- (NSNumberFormatter *) numberFormatter
{
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
  return nil;
}

- (NSString *) stringFromMeters: (double)numberInMeters
{
  return nil;
}

- (NSString *) unitStringFromValue: (double)value unit: (NSLengthFormatterUnit)unit
{
  return nil;
}

- (NSString *) unitStringFromMeters: (double)numberInMeters usedUnit: (NSLengthFormatterUnit *)unit
{
  return nil;
}

- (BOOL)getObjectValue: (id*)obj forString: (NSString *)string errorDescription: (NSString **)error
{
  return NO;
}

@end

