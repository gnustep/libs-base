/* Implementation of class NSDateComponentsFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory Casamento <greg.casamento@gmail.com>
   Date: Wed Nov  6 00:24:02 EST 2019

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

#include <Foundation/NSDateComponentsFormatter.h>

@implementation NSDateComponentsFormatter
  
- (NSString *) stringForObjectValue: (id)obj
{
  return nil;
}

- (NSString *) stringFromDateComponents: (NSDateComponents *)components
{
  return nil;
}

- (NSString *) stringFromDate: (NSDate *)startDate toDate:(NSDate *)endDate
{
  return nil;
}

- (NSString *) stringFromTimeInterval: (NSTimeInterval)ti
{
  return nil;
}

- (NSDateComponentsFormatterUnitsStyle) unitsStyle
{
  return _unitsStyle;
}

- (void) setUnitsStyle: (NSDateComponentsFormatterUnitsStyle)style
{
  _unitsStyle = style;
}
  
- (NSCalendarUnit) allowedUnits
{
  return _allowedUnits;
}

- (void) setAllowedUnits: (NSCalendarUnit)units
{
  _allowedUnits = units;
}

- (NSDateComponentsFormatterZeroFormattingBehavior) zeroFormattingBehavior
{
  return _zeroFormattingBehavior;
}

- (void) setZeroFormattingBehavior: (NSDateComponentsFormatterZeroFormattingBehavior)behavior;
{
  _zeroFormattingBehavior = behavior;
}

- (NSCalendar *) calendar
{
  return _calendar;
}

- (void) setCalender: (NSCalendar *)calendar
{
  ASSIGNCOPY(_calendar, calendar);
}

- (NSDate *) referenceDate
{
  return _referenceDate;
}

- (void) setReferenceDate: (NSDate *)referenceDate
{
  ASSIGNCOPY(_referenceDate, referenceDate);
}

- (BOOL) allowsFractionalUnits
{
  return _allowsFractionalUnits;
}

- (void) setAllowsFractionalUnits: (BOOL)allowsFractionalUnits
{
  _allowsFractionalUnits = allowsFractionalUnits;
}

- (NSInteger) maximumUnitCount
{
  return _maximumUnitCount;
}

- (void) setMaximumUnitCount: (NSInteger)maximumUnitCount
{
  _maximumUnitCount = maximumUnitCount;
}

- (BOOL) collapsesLargestUnit
{
  return _collapsesLargestUnit;
}

- (void) setCollapsesLargestUnit: (BOOL)collapsesLargestUnit
{
  _collapsesLargestUnit = collapsesLargestUnit;
}

- (BOOL) includesApproximationPhrase
{
  return _includesApproximationPhrase;
}

- (void) setIncludesApproximationPhrase: (BOOL)includesApproximationPhrase
{
  _includesApproximationPhrase = includesApproximationPhrase;
}

- (NSFormattingContext) formattingContext
{
  return _formattingContext;
}

- (void) setFormattingContext: (NSFormattingContext)formattingContext
{
  _formattingContext = formattingContext;
}

- (BOOL) getObjectValue: (id*)obj forString: (NSString *)string errorDescription: (NSString **)error
{
  return NO;
}

+ (NSString *) localizedStringFromDateComponents: (NSDateComponents *)components
                                      unitsStyle: (NSDateComponentsFormatterUnitsStyle)unitsStyle
{
  return nil;
}
  
@end

