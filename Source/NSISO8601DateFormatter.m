/** Implementation of class NSISO8601DateFormatter
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Tue Oct 29 04:43:13 EDT 2019

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

#import "Foundation/NSCoder.h"
#import "Foundation/NSDateFormatter.h"
#import "Foundation/NSISO8601DateFormatter.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"

@implementation NSISO8601DateFormatter

- (NSString *) _buildFormatWithOptions
{
  NSMutableString *result = [NSMutableString string];
  BOOL hasDateComponent = NO;
  BOOL hasTimeComponent = NO;

  // Check if using week-based year format (ISO 8601 Week Date)
  if (_formatOptions & NSISO8601DateFormatWithWeekOfYear)
    {
      // Week-based year format: YYYY-Www-D or YYYYWwwD
      if (_formatOptions & NSISO8601DateFormatWithYear)
        {
          [result appendString: @"YYYY"]; // ISO week-numbering year
        }
      if (_formatOptions & NSISO8601DateFormatWithDashSeparatorInDate)
        {
          [result appendString: @"-"];
        }
      [result appendString: @"'W'"]; // Week designator
      [result appendString: @"ww"]; // Week of year
      hasDateComponent = YES;
      
      if (_formatOptions & NSISO8601DateFormatWithDay)
        {
          if (_formatOptions & NSISO8601DateFormatWithDashSeparatorInDate)
            {
              [result appendString: @"-"];
            }
          [result appendString: @"e"]; // Day of week (1-7)
          hasDateComponent = YES;
        }
    }
  else
    {
      // Calendar date format: YYYY-MM-DD or YYYYMMDD
      if (_formatOptions & NSISO8601DateFormatWithYear)
        {
          [result appendString: @"yyyy"];
          hasDateComponent = YES;
        }
      if ((_formatOptions & NSISO8601DateFormatWithDashSeparatorInDate)
          && (_formatOptions & NSISO8601DateFormatWithMonth))
        {
          [result appendString: @"-"];
        }
      if (_formatOptions & NSISO8601DateFormatWithMonth)
        {
          [result appendString: @"MM"];
          hasDateComponent = YES;
        }
      if ((_formatOptions & NSISO8601DateFormatWithDashSeparatorInDate)
          && (_formatOptions & NSISO8601DateFormatWithDay))
        {
          [result appendString: @"-"];
        }
      if (_formatOptions & NSISO8601DateFormatWithDay)
        {
          [result appendString: @"dd"];
          hasDateComponent = YES;
        }
    }
  
  // Check if we have time component
  hasTimeComponent = (_formatOptions & NSISO8601DateFormatWithTime) != 0;
  
  // Add separator between date and time if both are present
  if (hasDateComponent && hasTimeComponent)
    {
      if (_formatOptions & NSISO8601DateFormatWithSpaceBetweenDateAndTime)
        {
          [result appendString: @" "];
        }
      else
        {
          [result appendString: @"'T'"];
        }
    }
  
  // Build time component
  if (_formatOptions & NSISO8601DateFormatWithTime)
    {
      if (_formatOptions & NSISO8601DateFormatWithColonSeparatorInTime)
        {
          [result appendString: @"HH:mm:ss"];
        }
      else
        {
          [result appendString: @"HHmmss"];
        }
      
      // Add fractional seconds if requested
      if (_formatOptions & NSISO8601DateFormatWithFractionalSeconds)
        {
          [result appendString: @".SSS"];
        }
    }
  
  // Add time zone
  if (_formatOptions & NSISO8601DateFormatWithTimeZone)
    {
      if (_formatOptions & NSISO8601DateFormatWithColonSeparatorInTimeZone)
        {
          [result appendString: @"ZZZZZ"]; // e.g., +00:00 or Z
        }
      else
        {
          [result appendString: @"ZZZ"]; // e.g., +0000
        }
    }
  
  return result;
}

- (NSDate *) dateFromString: (NSString *)string
{
  NSString *formatString = [self _buildFormatWithOptions];

  [_formatter setTimeZone: _timeZone];
  [_formatter setDateFormat: formatString];
  return [_formatter dateFromString: string];
}

- (oneway void) dealloc
{
  RELEASE(_formatter);
  RELEASE(_timeZone);
  [super dealloc];
}
 
- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _timeZone forKey: @"NS.timeZone"];
      [coder encodeInteger: _formatOptions forKey: @"NS.formatOptions"];
    }
  else
    {
      [coder encodeObject: _timeZone];
      [coder encodeValueOfObjCType: @encode(NSUInteger) at: &_formatOptions];
    }
}

- (NSISO8601DateFormatOptions) formatOptions
{
  return _formatOptions;
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _formatter = [[NSDateFormatter alloc] init];
      _timeZone = RETAIN([NSTimeZone localTimeZone]);
      _formatOptions = NSISO8601DateFormatWithInternetDateTime;
    }
  return self;
}

- (id) initWithCoder: (NSCoder *)decoder
{
  if ((self = [super initWithCoder: decoder]) != nil)
    {
      _formatter = [[NSDateFormatter alloc] init];
      if ([decoder allowsKeyedCoding])
        {
          ASSIGN(_timeZone, [decoder decodeObjectForKey: @"NS.timeZone"]);
          _formatOptions = [decoder decodeIntegerForKey: @"NS.formatOptions"];
        }
      else
        {
          ASSIGN(_timeZone, [decoder decodeObject]);
          [decoder decodeValueOfObjCType: @encode(NSUInteger)
				      at: &_formatOptions];
        }
    }
  return self;
}
- (void) setFormatOptions: (NSISO8601DateFormatOptions)options
{
  _formatOptions = options;
}
  
- (void) setTimeZone: (NSTimeZone *)tz
{
  _timeZone = tz;
}

- (NSString *) stringFromDate: (NSDate *)date
{
  NSString *formatString = [self _buildFormatWithOptions];

  [_formatter setTimeZone: _timeZone];
  [_formatter setDateFormat: formatString];
  return [_formatter stringFromDate: date];
}

- (NSString *) stringForObjectValue: (id)obj
{
  if ([obj isKindOfClass: [NSDate class]])
    {
      return [self stringFromDate: obj];
    }
  
  return nil;
}

+ (NSString *) stringFromDate: (NSDate *)date
                     timeZone: (NSTimeZone *)timeZone
                formatOptions: (NSISO8601DateFormatOptions)formatOptions
{
  NSISO8601DateFormatter *formatter;

  formatter = AUTORELEASE([[NSISO8601DateFormatter alloc] init]);
  [formatter setTimeZone: timeZone];
  [formatter setFormatOptions: formatOptions];
  return [formatter stringFromDate: date];
}

- (NSTimeZone *) timeZone
{
  return _timeZone;
}

@end

