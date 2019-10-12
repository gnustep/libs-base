
/* Implementation of class NSDateInterval
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
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

@implementation NSDateInterval

// Init
- (instancetype)init
{
}

- (instancetype)initWithStartDate:(NSDate *)startDate 
                         duration:(NSTimeInterval)duration
{
}

- (instancetype)initWithStartDate:(NSDate *)startDate 
                          endDate:(NSDate *)endDate
{
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
}

- (void) encodeWithCoder: (NSCoder *)coder
{
}

- (id) copyWithZone: (NSZone *)zone
{
}

// Access
- (NSDate *) startDate
{
}

- (void) setStartDate: (NSDate *)startDate
{
}

- (NSDate *) endDate
{
}

- (void) setEndDate: (NSDate *)endDate
{
}

- (NSTimeInterval) duration
{
}

- (void) setDuration: (NSTimeInterval)duration
{
}

// Compare
- (NSComparisonResult) compare: (NSDateInterval *)dateInterval
{
}

- (BOOL) isEqualToDateInterval: (NSDateInterval *)dateInterval
{
}

// Determine
- (BOOL) intersectsDateInterval: (NSDateInterval *)dateInterval
{
}

- (NSDateInterval *) intersectionWithDateInterval: (NSDateInterval *)dateInterval
{
}

// Contain
- (BOOL) containsDate: (NSDate *)date
{
}

@end

