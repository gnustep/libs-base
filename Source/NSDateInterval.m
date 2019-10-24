/* Implementation of class NSDateInterval
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory Casamento <greg.casamento@gmail.com>
   Date: Wed Oct  9 16:24:13 EDT 2019

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

#include <Foundation/NSDateInterval.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSArray.h>

@implementation NSDateInterval

// Init
- (instancetype)init
{
  self = [super init];
  if(self != nil)
    {
      _startDate = [NSDate date];
      _duration = 0.0;
      RETAIN(_startDate);
    }
  return self;
}

- (instancetype)initWithStartDate:(NSDate *)startDate 
                         duration:(NSTimeInterval)duration
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_startDate, startDate);
      _duration = duration;
    }
  return self;
}

- (instancetype)initWithStartDate:(NSDate *)startDate 
                          endDate:(NSDate *)endDate
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_startDate, startDate);
      _duration = [endDate timeIntervalSinceDate: startDate];
    }
  return self;  
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  return nil;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

- (id) copyWithZone: (NSZone *)zone
{
  return [[[self class] allocWithZone: zone]
           initWithStartDate: _startDate
                    duration: _duration];
}

- (void) dealloc
{
  RELEASE(_startDate);
  [super dealloc];
}

// Access
- (NSDate *) startDate
{
  return _startDate;
}

- (void) setStartDate: (NSDate *)startDate
{
  ASSIGNCOPY(_startDate, startDate);
}

- (NSDate *) endDate
{
  return [_startDate dateByAddingTimeInterval: _duration];
}

- (void) setEndDate: (NSDate *)endDate
{
  _duration = [endDate timeIntervalSinceDate: _startDate];
}

- (NSTimeInterval) duration
{
  return _duration;
}

- (void) setDuration: (NSTimeInterval)duration
{
  _duration = duration;
}

// Compare
- (NSComparisonResult) compare: (NSDateInterval *)dateInterval
{
  // NSOrderedAscending
  if([_startDate isEqualToDate: [dateInterval startDate]] &&
     _duration < [dateInterval duration])
    return NSOrderedAscending;
  
  if([_startDate compare: [dateInterval startDate]] == NSOrderedAscending)
    return NSOrderedAscending;

  // NSOrderedSame 
  if([self isEqualToDateInterval: dateInterval])
    return NSOrderedSame;

  // NSOrderedDescending
  if([_startDate isEqualToDate: [dateInterval startDate]] &&
     _duration > [dateInterval duration])
    return NSOrderedDescending;
  
  if([_startDate compare: [dateInterval startDate]] == NSOrderedDescending)
    return NSOrderedDescending;

  return 0;
}

- (BOOL) isEqualToDateInterval: (NSDateInterval *)dateInterval
{
  return ([_startDate isEqualToDate: [dateInterval startDate]] &&
          _duration == [dateInterval duration]);
}

// Determine
- (BOOL) intersectsDateInterval: (NSDateInterval *)dateInterval
{
  return [self intersectionWithDateInterval: dateInterval] != nil;
}

- (NSDateInterval *) intersectionWithDateInterval: (NSDateInterval *)dateInterval
{
  NSDateInterval *result = nil;
  NSArray *array = [NSArray arrayWithObjects: self, dateInterval, nil];
  NSArray *sortedArray = [array sortedArrayUsingSelector: @selector(compare:)];
  NSDateInterval *first = [sortedArray firstObject];
  NSDateInterval *last = [sortedArray lastObject];
  NSDate *intersectStartDate = nil;
  NSDate *intersectEndDate = nil;

  // Max of start date....
  if([[first startDate] compare: [last startDate]] == NSOrderedAscending ||
     [[first startDate] isEqualToDate: [last startDate]])
    {
      intersectStartDate = [last startDate];
    }
  if([[first startDate] compare: [last startDate]] == NSOrderedDescending)
    {
      intersectStartDate = [first startDate];
    }

  // Min of end date...
  if([[first endDate] compare: [last endDate]] == NSOrderedDescending ||
     [[first endDate] isEqualToDate: [last endDate]])
    {
      intersectEndDate = [last endDate];
    }
  if([[first endDate] compare: [last endDate]] == NSOrderedAscending)
    {
      intersectEndDate = [first endDate];
    }

  if([intersectStartDate compare: intersectEndDate] == NSOrderedAscending)
    {
      result = [[NSDateInterval alloc] initWithStartDate: intersectStartDate
                                                 endDate: intersectEndDate];
      AUTORELEASE(result);
    }

  return result;
}

// Contain
- (BOOL) containsDate: (NSDate *)date
{
  NSDate *endDate = [self endDate];
  return ([_startDate compare: date] == NSOrderedSame ||
          [endDate compare: date] == NSOrderedSame ||
          ([_startDate compare: date] == NSOrderedAscending &&
           [endDate compare: date] == NSOrderedDescending));
    
}

@end

