/* NSCalendar.h

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

#ifndef __NSCalendar_h_GNUSTEP_BASE_INCLUDE
#define __NSCalendar_h_GNUSTEP_BASE_INCLUDE

#import <GNUstepBase/GSVersionMacros.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST)

#include <Foundation/NSObject.h>
#include <Foundation/NSGeometry.h>

@class NSDate;
@class NSCalendar;
@class NSLocale;
@class NSString;
@class NSTimeZone;

#if	defined(__cplusplus)
extern "C" {
#endif

typedef NSUInteger NSCalendarUnit;
enum
{
  NSEraCalendarUnit = (1UL << 1),
  NSYearCalendarUnit = (1UL << 2),
  NSMonthCalendarUnit = (1UL << 3),
  NSDayCalendarUnit = (1UL << 4),
  NSHourCalendarUnit = (1UL << 5),
  NSMinuteCalendarUnit = (1UL << 6),
  NSSecondCalendarUnit = (1UL << 7),
  NSWeekCalendarUnit = (1UL << 8),
  NSWeekdayCalendarUnit = (1UL << 9),
  NSWeekdayOrdinalCalendarUnit = (1UL << 10),
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  NSQuarterCalendarUnit = (1UL << 11)
#endif
};

enum
{
  NSWrapCalendarComponents = (1UL << 0)
};

enum
{
  NSUndefinedDateComponent = 0x7fffffff
};



@interface NSDateComponents : NSObject <NSCopying>
{
  NSInteger _era;
  NSInteger _year;
  NSInteger _month;
  NSInteger _day;
  NSInteger _hour;
  NSInteger _minute;
  NSInteger _second;
  NSInteger _week;
  NSInteger _weekday;
  NSInteger _weekdayOrdinal;
  NSInteger _quarter;
// FIXME: In reality these are only available on iOS > 4.  Will probably show
// up in OS X 10.7.
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  NSCalendar *_cal;
  NSTimeZone *_tz;
#endif
}

- (NSInteger) day;
- (NSInteger) era;
- (NSInteger) hour;
- (NSInteger) minute;
- (NSInteger) month;
- (NSInteger) second;
- (NSInteger) week;
- (NSInteger) weekday;
- (NSInteger) weekdayOrdinal;
- (NSInteger) year;

- (void) setDay: (NSInteger) v;
- (void) setEra: (NSInteger) v;
- (void) setHour: (NSInteger) v;
- (void) setMinute: (NSInteger) v;
- (void) setMonth: (NSInteger) v;
- (void) setSecond: (NSInteger) v;
- (void) setWeek: (NSInteger) v;
- (void) setWeekday: (NSInteger) v;
- (void) setWeekdayOrdinal: (NSInteger) v;
- (void) setYear: (NSInteger) v;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
- (NSInteger) quarter;
- (void) setQuarter: (NSInteger) v;
#endif

// FIXME: In reality these are only available on iOS > 4.
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
- (NSCalendar *) calendar;
- (NSTimeZone *) timeZone;
- (void) setCalendar: (NSCalendar *) cal;
- (void) setTimeZone: (NSTimeZone *) tz;
#endif
@end



@interface NSCalendar : NSObject <NSCoding, NSCopying>
{
  NSString   *_identifier;
  NSString   *_localeId;
  NSTimeZone *_tz;
  void       *_cal;
}

+ (id) currentCalendar;

- (id) initWithCalendarIdentifier: (NSString *) string;
- (NSString *) calendarIdentifier;

- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) date;
- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) startingDate
                           toDate: (NSDate *) resultDate
                          options: (NSUInteger) opts;
- (NSDate *) dateByAddingComponents: (NSDateComponents *) comps
                             toDate: (NSDate *) date
                            options: (NSUInteger) opts;
- (NSDate *) dateFromComponents: (NSDateComponents *) comps;

- (NSLocale *) locale;
- (void)setLocale: (NSLocale *) locale;
- (NSUInteger) firstWeekday;
- (void) setFirstWeekday: (NSUInteger) weekday;
- (NSUInteger) minimumDaysInFirstWeek;
- (void) setMinimumDaysInFirstWeek: (NSUInteger) mdw;
- (NSTimeZone *) timeZone;
- (void) setTimeZone: (NSTimeZone *) tz;

- (NSRange) maximumRangeOfUnit: (NSCalendarUnit) unit;
- (NSRange) minimumRangeofUnit: (NSCalendarUnit) unit;
- (NSUInteger) ordinalityOfUnit: (NSCalendarUnit) smaller
                         inUnit: (NSCalendarUnit) larger
                        forDate: (NSDate *) date;
- (NSRange) rangeOfUnit: (NSCalendarUnit) smaller
                 inUnit: (NSCalendarUnit) larger
                forDate: (NSDate *) date;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_5, GS_API_LATEST)
+ (id) autoupdatingCurrentCalendar;

- (BOOL) rangeOfUnit: (NSCalendarUnit) unit
           startDate: (NSDate **) datep
            interval: (NSTimeInterval *)tip
             forDate: (NSDate *)date;
#endif
@end

#if	defined(__cplusplus)
}
#endif

#endif /* OS_API_VERSION(MAC_OS_X_VERSION_10_4, GS_API_LATEST) */

#endif /* __NSCalendar_h_GNUSTEP_BASE_INCLUDE */
