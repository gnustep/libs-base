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
#import "Foundation/NSDictionary.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"

#if defined(HAVE_UNICODE_UCAL_H)
#include <unicode/ucal.h>
#endif



#if GS_USE_ICU == 1
static UCalendarDateFields _NSCalendarUnitToDateField (NSCalendarUnit unit)
{
  // I'm just going to go in the order they appear in Apple's documentation
  if (unit & NSEraCalendarUnit)
    return UCAL_ERA;
  if (unit & NSYearCalendarUnit)
    return UCAL_YEAR;
  if (unit & NSMonthCalendarUnit)
    return UCAL_MONTH;
  if (unit & NSDayCalendarUnit)
    return UCAL_DAY_OF_MONTH;
  if (unit & NSHourCalendarUnit)
    return UCAL_HOUR_OF_DAY;
  if (unit & NSMinuteCalendarUnit)
    return UCAL_MINUTE;
  if (unit & NSSecondCalendarUnit)
    return UCAL_SECOND;
  if (unit & NSWeekCalendarUnit)
    return UCAL_WEEK_OF_YEAR;
  if (unit & NSWeekdayCalendarUnit)
    return UCAL_DAY_OF_WEEK;
  if (unit & NSWeekdayOrdinalCalendarUnit)
    // FIXME: Is this right???
    return UCAL_DAY_OF_WEEK_IN_MONTH;
  // ICU doesn't include a quarter DateField...
  
  return -1;
}
#endif /* GS_USE_ICU */

@interface NSCalendar (PrivateMethods)
- (void) _openCalendar;
- (void) _closeCalendar;
- (NSString *) _localeIdWithLocale: (NSLocale *) locale;
@end

#define TZ_NAME_LENGTH 1024

@implementation NSCalendar (PrivateMethods)
- (void) _openCalendar
{
#if GS_USE_ICU == 1
  if (_cal == NULL)
    {
      NSString *tzName;
      NSUInteger tzLen;
      unichar cTzId[TZ_NAME_LENGTH];
      const char *cLocaleId;
      UErrorCode err = U_ZERO_ERROR;
      
      cLocaleId = [_localeId UTF8String];
      tzName = [_tz name];
      tzLen = [tzName length];
      if (tzLen > TZ_NAME_LENGTH)
        tzLen = TZ_NAME_LENGTH;
      [tzName getCharacters: cTzId range: NSMakeRange(0, tzLen)];

#ifndef	UCAL_DEFAULT
/*
 * Older versions of ICU used UCAL_TRADITIONAL rather than UCAL_DEFAULT
 * so if one is not available we use the other.
 */      
#define	UCAL_DEFAULT UCAL_TRADITIONAL
#endif
      _cal = 
        ucal_open ((const UChar *)cTzId, tzLen, cLocaleId, UCAL_DEFAULT, &err);
    }
#endif
}

- (void) _closeCalendar
{
#if GS_USE_ICU == 1
  ucal_close (_cal);
  _cal = NULL;
#endif
}

- (NSString *) _localeIdWithLocale: (NSLocale *) locale
{
  NSString *result;
  NSString *localeId;
  NSMutableDictionary *tmpDict;
  
  localeId = [locale localeIdentifier];
  tmpDict = [[NSLocale componentsFromLocaleIdentifier: localeId]
    mutableCopyWithZone: NULL];
  [tmpDict setObject: _identifier forKey: NSLocaleCalendarIdentifier];
  result = [NSLocale localeIdentifierFromComponents: tmpDict];
  RELEASE(tmpDict);
  
  return result;
}
@end

@implementation NSCalendar

+ (id) currentCalendar
{
  NSCalendar *result = nil;
  NSLocale *locale;
  
  locale = [NSLocale currentLocale];
  
  // FIXME
  
  return result;
}

- (id) initWithCalendarIdentifier: (NSString *) string
{
  if ([string isEqualToString: NSGregorianCalendar])
    _identifier = NSGregorianCalendar;
  else if ([string isEqualToString: NSBuddhistCalendar])
    _identifier = NSBuddhistCalendar;
  else if ([string isEqualToString: NSChineseCalendar])
    _identifier = NSChineseCalendar;
  else if ([string isEqualToString: NSHebrewCalendar])
    _identifier = NSHebrewCalendar;
  else if ([string isEqualToString: NSIslamicCalendar])
    _identifier = NSIslamicCalendar;
  else if ([string isEqualToString: NSIslamicCivilCalendar])
    _identifier = NSIslamicCivilCalendar;
  else if ([string isEqualToString: NSJapaneseCalendar])
    _identifier = NSJapaneseCalendar;
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  else if ([string isEqualToString: NSRepublicOfChinaCalendar])
    _identifier = NSRepublicOfChinaCalendar;
  else if ([string isEqualToString: NSPersianCalendar])
    _identifier = NSPersianCalendar;
  else if ([string isEqualToString: NSIndianCalendar])
    _identifier = NSIndianCalendar;
  else if ([string isEqualToString: NSISO8601Calendar])
    _identifier = NSISO8601Calendar;
#endif
  else
    {
      RELEASE(self);
      return nil;
    }
  
  // It's much easier to keep a copy of the NSLocale's string representation
  // than to have to build it everytime we have to open a UCalendar.
  _localeId = RETAIN([self _localeIdWithLocale: [NSLocale currentLocale]]);
  _tz = RETAIN([NSTimeZone defaultTimeZone]);
  
  return self;
}

- (void) dealloc
{
  [self _closeCalendar];
  RELEASE(_identifier);
  RELEASE(_localeId);
  RELEASE(_tz);
  
  [super dealloc];
}

- (NSString *) calendarIdentifier
{
  return _identifier;
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
#if GS_USE_ICU == 1
  int32_t amount;
  UErrorCode err = U_ZERO_ERROR;
  UDate udate;
  
  [self _openCalendar];
  udate = (UDate)([date timeIntervalSince1970] * 1000.0);
  ucal_setMillis (_cal, udate, &err);
  
#define _ADD_COMPONENT(c, n) \
  if (opts & NSWrapCalendarComponents) \
    ucal_roll (_cal, c, n, &err); \
  else \
    ucal_add (_cal, c, n, &err);
  if ((amount = (int32_t)[comps day]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_DAY_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps era]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_ERA, amount);
    }
  if ((amount = (int32_t)[comps hour]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_HOUR_OF_DAY, amount);
    }
  if ((amount = (int32_t)[comps minute]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_MINUTE, amount);
    }
  if ((amount = (int32_t)[comps month]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_MONTH, amount);
    }
  if ((amount = (int32_t)[comps second]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_SECOND, amount);
    }
  if ((amount = (int32_t)[comps week]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_WEEK_OF_YEAR, amount);
    }
  if ((amount = (int32_t)[comps weekday]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_DAY_OF_WEEK, amount);
    }
#undef _ADD_COMPONENT
  
  udate = ucal_getMillis (_cal, &err);
  if (U_FAILURE(err))
    return nil;
  
  return [NSDate dateWithTimeIntervalSince1970: (udate / 1000.0)];
#else
  return nil;
#endif
}

- (NSDate *) dateFromComponents: (NSDateComponents *) comps
{
#if GS_USE_ICU == 1
  int32_t amount;
  UDate udate;
  UErrorCode err = U_ZERO_ERROR;
  
  [self _openCalendar];
  ucal_clear (_cal);
  
  if ((amount = (int32_t)[comps day]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_DAY_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps era]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_ERA, amount);
    }
  if ((amount = (int32_t)[comps hour]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_HOUR_OF_DAY, amount);
    }
  if ((amount = (int32_t)[comps minute]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_MINUTE, amount);
    }
  if ((amount = (int32_t)[comps month]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_MONTH, amount);
    }
  if ((amount = (int32_t)[comps second]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_SECOND, amount);
    }
  if ((amount = (int32_t)[comps week]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_WEEK_OF_YEAR, amount);
    }
  if ((amount = (int32_t)[comps weekday]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_DAY_OF_WEEK, amount);
    }
  
  udate = ucal_getMillis (_cal, &err);
  if (U_FAILURE(err))
    return nil;
  
  return [NSDate dateWithTimeIntervalSince1970: (udate / 1000.0)];
#else
  return nil;
#endif
}

- (NSLocale *) locale
{
  return AUTORELEASE([[NSLocale alloc] initWithLocaleIdentifier: _localeId]);
}

- (void)setLocale: (NSLocale *) locale
{
  if ([[locale localeIdentifier] isEqual: _localeId])
    return;
  
  [self _closeCalendar];
  RELEASE(_localeId);
  _localeId = RETAIN([self _localeIdWithLocale: locale]);
}

- (NSUInteger) firstWeekday
{
#if GS_USE_ICU == 1
  [self _openCalendar];
  return ucal_getAttribute (_cal, UCAL_FIRST_DAY_OF_WEEK);
#endif
  return 0;
}

- (void) setFirstWeekday: (NSUInteger) weekday
{
#if GS_USE_ICU == 1
  [self _openCalendar];
  ucal_setAttribute (_cal, UCAL_FIRST_DAY_OF_WEEK, (int32_t)weekday);
#endif
  return;
}

- (NSUInteger) minimumDaysInFirstWeek
{
#if GS_USE_ICU == 1
  [self _openCalendar];
  return ucal_getAttribute (_cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK);
#endif
  return 1;
}

- (void) setMinimumDaysInFirstWeek: (NSUInteger) mdw
{
#if GS_USE_ICU == 1
  [self _openCalendar];
  ucal_setAttribute (_cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK, (int32_t)mdw);
#endif
  return;
}

- (NSTimeZone *) timeZone
{
  return _tz;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  if ([tz isEqual: _tz])
    return;
  
  [self _closeCalendar];
  RELEASE(_tz);
  _tz = RETAIN(tz);
}


- (NSRange) maximumRangeOfUnit: (NSCalendarUnit) unit
{
#if GS_USE_ICU == 1
  UCalendarDateFields dateField;
  NSRange result;
  UErrorCode err = U_ZERO_ERROR;
  
  [self _openCalendar];
  dateField = _NSCalendarUnitToDateField (unit);
  // We really don't care if there are any errors...
  result.location =
    (NSUInteger)ucal_getLimit (_cal, dateField, UCAL_MINIMUM, &err);
  result.length = 
    (NSUInteger)ucal_getLimit (_cal, dateField, UCAL_MAXIMUM, &err)
    - result.location + 1;
  // ICU's month is 0-based, while NSCalendar is 1-based
  if (dateField == UCAL_MONTH)
    result.location += 1;
  
  return result;
#else
  return NSMakeRange (0, 0);
#endif
}

- (NSRange) minimumRangeofUnit: (NSCalendarUnit) unit
{
#if GS_USE_ICU == 1
  UCalendarDateFields dateField;
  NSRange result;
  UErrorCode err = U_ZERO_ERROR;
  
  [self _openCalendar];
  dateField = _NSCalendarUnitToDateField (unit);
  // We really don't care if there are any errors...
  result.location =
    (NSUInteger)ucal_getLimit (_cal, dateField, UCAL_GREATEST_MINIMUM, &err);
  result.length = 
    (NSUInteger)ucal_getLimit (_cal, dateField, UCAL_LEAST_MAXIMUM, &err)
    - result.location + 1;
  // ICU's month is 0-based, while NSCalendar is 1-based
  if (dateField == UCAL_MONTH)
    result.location += 1;
  
  return result;
#else
  return NSMakeRange (0, 0);
#endif
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
             forDate: (NSDate *)date
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
#if OS_API_VERSION(MAC_OS_X_VERSION_10_6, GS_API_LATEST)
  _quarter = NSUndefinedDateComponent;
#endif
  
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

- (NSCalendar *) calendar
{
  return _cal;
}

- (NSTimeZone *) timeZone
{
  return _tz;
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

- (void) setCalendar: (NSCalendar *) cal
{
  if (_cal)
    RELEASE(_cal);
  
  _cal = RETAIN(cal);
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  if (_tz)
    RELEASE(_tz);
  
  _tz = RETAIN(tz);
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return NSCopyObject(self, 0, zone);
}

@end
