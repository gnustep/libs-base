/* Implementation of class NSISO8601DateFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Tue Oct 29 04:43:13 EDT 2019

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

#include <Foundation/NSISO8601DateFormatter.h>

@implementation NSISO8601DateFormatter

- (instancetype) init
{
  self = [super init];
  if(self != nil)
    {
    }
  return self;
}
  
- (NSTimeZone *) timeZone
{
  return _timeZone;
}

- (void) setTimeZone: (NSTimeZone *)tz
{
  _timeZone = tz;
}

- (NSISO8601DateFormatOptions) formatOptions
{
  return _formatOptions;
}

- (void) setFormatOptions: (NSISO8601DateFormatOptions)options
{
  _formatOptions = options;
}
  
- (NSString *) stringFromDate: (NSDate *)date
{
  return nil;
}

- (NSDate *) dateFromString: (NSString *)string
{
  return nil;
}

+ (NSString *) stringFromDate: (NSDate *)date
                     timeZone: (NSTimeZone *)timeZone
                formatOptions: (NSISO8601DateFormatOptions)formatOptions
{
  return nil;
}

@end

