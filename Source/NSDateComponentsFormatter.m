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
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>

@implementation NSDateComponentsFormatter

- (instancetype) init
{
  self = [super init];
  if(self != nil)
    {
      _calendar = nil;
      _referenceDate = nil;
      _allowsFractionalUnits = NO;
      _collapsesLargestUnit = NO;
      _includesApproximationPhrase = NO;
      _formattingContext = NSFormattingContextUnknown;
      _maximumUnitCount = 0;
      _zeroFormattingBehavior = NSDateComponentsFormatterZeroFormattingBehaviorNone;
      _allowedUnits = NSCalendarUnitYear |
        NSCalendarUnitMonth |
        NSCalendarUnitDay |
        NSCalendarUnitHour |
        NSCalendarUnitMinute |
        NSCalendarUnitSecond;
      _unitsStyle = NSDateComponentsFormatterUnitsStylePositional;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_calendar);
  RELEASE(_referenceDate);
  [super dealloc];
}

- (NSString *) stringForObjectValue: (id)obj
{
  NSString *result = nil;
  
  if([obj isKindOfClass: [NSDateComponents class]])
    {
      result = [self stringFromDateComponents: obj];
    }
  else if([obj isKindOfClass: [NSNumber class]])
    {
      NSTimeInterval ti = [obj longLongValue];
      result = [self stringFromTimeInterval: ti];
    }
    
  return result;
}

- (NSString *) stringFromDateComponents: (NSDateComponents *)components
{
  NSString *result = @"";

  if(_allowedUnits | NSCalendarUnitYear)
    {
    }
  if(_allowedUnits | NSCalendarUnitMonth)
    {
    }
  if(_allowedUnits | NSCalendarUnitDay)
    {
    }
  if(_allowedUnits | NSCalendarUnitHour)
    {
    }
  if(_allowedUnits | NSCalendarUnitMinute)
    {
    }
  if(_allowedUnits | NSCalendarUnitSecond)
    {
    }
  if(_allowedUnits | NSCalendarUnitWeekOfMonth)
    {
    }
  
  return result;
}

- (NSString *) stringFromDate: (NSDate *)startDate
                       toDate: (NSDate *)endDate
{
  NSDateComponents *dc = nil;
  NSCalendar *calendar = ( _calendar != nil ) ? _calendar : [NSCalendar currentCalendar];
  dc = [calendar components: _allowedUnits
                   fromDate: startDate
                     toDate: endDate
                    options: NSCalendarMatchStrictly];
  return [self stringFromDateComponents: dc];
}

- (NSString *) stringFromTimeInterval: (NSTimeInterval)ti
{
  NSDate *startDate = [NSDate date];
  NSDate *endDate = [startDate dateByAddingTimeInterval: (ti > 0) ? ti : -ti];
  return [self stringFromDate: startDate toDate: endDate];
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
  if(units | NSCalendarUnitYear &&
     units | NSCalendarUnitMonth &&
     units | NSCalendarUnitDay &&
     units | NSCalendarUnitHour &&
     units | NSCalendarUnitMinute &&
     units | NSCalendarUnitSecond &&
     units | NSCalendarUnitWeekOfMonth)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"Passed invalid unit into allowedUnits"];
    }
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
  NSDateComponentsFormatter *fmt = [[NSDateComponentsFormatter alloc] init];
  [fmt setUnitsStyle: unitsStyle];
  AUTORELEASE(fmt);
  return [fmt stringFromDateComponents: components];
}
  
@end

