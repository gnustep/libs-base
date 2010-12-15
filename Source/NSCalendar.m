/* NSCalendar.m

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by: Stefan Bidigaray
   Date: December, 2010

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#import "common.h"
#import "Foundation/NSCalendar.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"

#if defined(HAVE_UNICODE_UCAL_H)
#include <unicode/ucal.h>
#endif

@implementation NSCalendar

+ (id) currentCalendar
{
  return nil;
}

- (id) initWithCalendarIdentifier: (NSString *) string
{
  RELEASE(self);
  return nil;
}

- (NSString *) calendarIdentifier
{
  return nil;
}


- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) date
{
  return nil;
}

- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) startingDate
                           toDate: (NSDate *) resultDate
                          options: (NSUInteger) opts
{
  return nil;
}

- (NSDate *) dateByAddingComponents: (NSDateComponents *) comps
                             toDate: (NSDate *) date
                            options: (NSUInteger) opts
{
  return nil;
}

- (NSDate *) dateFromComponents: (NSDateComponents *) comps
{
  return nil;
}

- (NSLocale *) locale
{
  return _locale;
}

- (void)setLocale: (NSLocale *) locale
{
  _locale = locale;
}

- (NSUInteger) firstWeekday
{
  return 0;
}

- (void) setFirstWeekday: (NSUInteger) weekday
{
  return;
}

- (NSUInteger) minimumDayInFirstWeek
{
  return 0;
}

- (void) setMinimumDaysInFirstWeek: (NSUInteger) mdw
{
  return;
}

- (NSTimeZone *) timeZone
{
  return nil;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  _tz = tz;
}


- (NSRange) maximumRangeOfUnit: (NSCalendarUnit) unit
{
  return NSMakeRange (0, 0);
}

- (NSRange) minimumRangeofUnit: (NSCalendarUnit) unit
{
  return NSMakeRange (0, 0);
}

- (NSUInteger) ordinalityOfUnit: (NSCalendarUnit) smaller
                         inUnit: (NSCalendarUnit) larger
                        forDate: (NSDate *) date
{
  return 0;
}

- (NSRange) rangeOfUnit: (NSCalendarUnit) smaller
                 inUnit: (NSCalendarUnit) larger
                forDate: (NSDate *) date
{
  return NSMakeRange (0, 0);
}

+ (id) autoupdatingCurrentCalendar
{
  return nil;
}


- (BOOL) rangeOfUnit: (NSCalendarUnit) unit
           startDate: (NSDate **) datep
            interval: (NSTimeInterval *)tip
             forDate:(NSDate *)date
{
  return NO;
}
@end



@implementation NSDateComponents

- (id) init
{
  _era = NSUndefinedDateComponent;
  _year = NSUndefinedDateComponent;
  _month = NSUndefinedDateComponent;
  _day = NSUndefinedDateComponent;
  _hour = NSUndefinedDateComponent;
  _minute = NSUndefinedDateComponent;
  _second = NSUndefinedDateComponent;
  _week = NSUndefinedDateComponent;
  _weekday = NSUndefinedDateComponent;
  _weekdayOrdinal = NSUndefinedDateComponent;
  
  return self;
}

- (NSInteger) day
{
  return _day;
}

- (NSInteger) era
{
  return _era;
}

- (NSInteger) hour
{
  return _hour;
}

- (NSInteger) minute
{
  return _minute;
}

- (NSInteger) month
{
  return _month;
}

- (NSInteger) quarter
{
  return _quarter;
}

- (NSInteger) second
{
  return _second;
}

- (NSInteger) week
{
  return _week;
}

- (NSInteger) weekday
{
  return _weekday;
}

- (NSInteger) weekdayOrdinal
{
  return _weekdayOrdinal;
}

- (NSInteger) year
{
  return _year;
}



- (void) setDay: (NSInteger) v
{
  _day = v;
}

- (void) setEra: (NSInteger) v
{
  _era = v;
}

- (void) setHour: (NSInteger) v
{
  _hour = v;
}

- (void) setMinute: (NSInteger) v
{
  _minute = v;
}

- (void) setMonth: (NSInteger) v
{
  _month = v;
}

- (void) setQuarter: (NSInteger) v
{
  _quarter = v;
}

- (void) setSecond: (NSInteger) v
{
  _second = v;
}

- (void) setWeek: (NSInteger) v
{
  _week = v;
}

- (void) setWeekday: (NSInteger) v
{
  _weekday = v;
}

- (void) setWeekdayOrdinal: (NSInteger) v
{
  _weekdayOrdinal = v;
}

- (void) setYear: (NSInteger) v
{
  _year = v;
}

@end
