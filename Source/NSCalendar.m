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
#import "Foundation/NSCoder.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSLocale.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSUserDefaults.h"
#import "GNUstepBase/GSLock.h"

#if defined(HAVE_UNICODE_UCAL_H)
#define id ucal_id
#include <unicode/ucal.h>
#undef id
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
- (void) _resetCalendar;
- (void *) _UCalendar;
- (NSString *) _localeIdWithLocale: (NSLocale *) locale;
- (NSString *)_localeIdentifier;
- (void) _setLocaleIdentifier: (NSString *) identifier;
@end

#define TZ_NAME_LENGTH 1024

@implementation NSCalendar (PrivateMethods)
- (void) _resetCalendar
{
#if GS_USE_ICU == 1
  NSString *tzName;
  NSUInteger tzLen;
  unichar cTzId[TZ_NAME_LENGTH];
  const char *cLocaleId;
  UErrorCode err = U_ZERO_ERROR;
  
  if (_cal != NULL)
    ucal_close (_cal);
  
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
#endif
}

- (void *) _UCalendar
{
  return _cal;
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

- (NSString *)_localeIdentifier
{
  return _localeId;
}

- (void) _setLocaleIdentifier: (NSString *) identifier
{
  if ([identifier isEqualToString: _localeId])
    return;
  
  RELEASE(_localeId);
  _localeId = RETAIN(identifier);
  [self _resetCalendar];
}
@end

@implementation NSCalendar

static NSCalendar *autoupdatingCalendar = nil;
static NSRecursiveLock *classLock = nil;

+ (void) initialize
{
  if (self == [NSLocale class])
    classLock = [GSLazyRecursiveLock new];
}

+ (void) defaultsDidChange: (NSNotification*)n
{
  NSUserDefaults *defs;
  NSString *locale;
  NSString *calendar;
  NSString *tz;

  defs = [NSUserDefaults standardUserDefaults];
  locale = [defs stringForKey: @"Locale"];
  calendar = [defs stringForKey: @"Calendar"];
  tz = [defs stringForKey: @"Local Time Zone"];
  
  if ([locale isEqual: autoupdatingCalendar->_localeId] == NO
      || [calendar isEqual: autoupdatingCalendar->_identifier] == NO
      || [tz isEqual: [(autoupdatingCalendar->_tz) name]] == NO)
    {
      [classLock lock];
      RELEASE(autoupdatingCalendar->_localeId);
      RELEASE(autoupdatingCalendar->_identifier);
      RELEASE(autoupdatingCalendar->_tz);
#if GS_USE_ICU == 1
      ucal_close(autoupdatingCalendar->_cal);
#endif
      
      autoupdatingCalendar->_localeId = RETAIN(locale);
      autoupdatingCalendar->_identifier = RETAIN(calendar);
      autoupdatingCalendar->_tz = [[NSTimeZone alloc] initWithName: tz];
      
      [autoupdatingCalendar _resetCalendar];
      [classLock unlock];
    }
}

+ (id) currentCalendar
{
  NSCalendar *result;
  NSLocale *locale;
  NSCalendar *cal;
  
  locale = [NSLocale currentLocale];
  cal = [locale objectForKey: NSLocaleCalendar];
  result =
    [[NSCalendar alloc] initWithCalendarIdentifier: [cal calendarIdentifier]];
  
  return AUTORELEASE(result);
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
  else if ([string isEqualToString: NSRepublicOfChinaCalendar])
    _identifier = NSRepublicOfChinaCalendar;
  else if ([string isEqualToString: NSPersianCalendar])
    _identifier = NSPersianCalendar;
  else if ([string isEqualToString: NSIndianCalendar])
    _identifier = NSIndianCalendar;
  else if ([string isEqualToString: NSISO8601Calendar])
    _identifier = NSISO8601Calendar;
  else
    {
      RELEASE(self);
      return nil;
    }
  
  // It's much easier to keep a copy of the NSLocale's string representation
  // than to have to build it everytime we have to open a UCalendar.
  _localeId = RETAIN([self _localeIdWithLocale: [NSLocale currentLocale]]);
  _tz = RETAIN([NSTimeZone defaultTimeZone]);
  
  [self _resetCalendar];
  return self;
}

- (void) dealloc
{
#if GS_USE_ICU == 1
  ucal_close (_cal);
#endif
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
#if GS_USE_ICU == 1
  NSDateComponents *comps;
  UErrorCode err = U_ZERO_ERROR;
  UDate udate;
  
  udate = (UDate)floor([date timeIntervalSince1970] * 1000.0);
  ucal_setMillis (_cal, udate, &err);
  if (U_FAILURE(err))
    return nil;
  
  comps = [[NSDateComponents alloc] init];
  if (unitFlags & NSEraCalendarUnit)
    [comps setEra: ucal_get (_cal, UCAL_ERA, &err)];
  if (unitFlags & NSYearCalendarUnit)
    [comps setYear: ucal_get (_cal, UCAL_YEAR, &err)];
  if (unitFlags & NSMonthCalendarUnit)
    [comps setMonth: ucal_get (_cal, UCAL_MONTH, &err)];
  if (unitFlags & NSDayCalendarUnit)
    [comps setDay: ucal_get (_cal, UCAL_DAY_OF_MONTH, &err)];
  if (unitFlags & NSHourCalendarUnit)
    [comps setHour: ucal_get (_cal, UCAL_HOUR_OF_DAY, &err)];
  if (unitFlags & NSMinuteCalendarUnit)
    [comps setMinute: ucal_get (_cal, UCAL_MINUTE, &err)];
  if (unitFlags & NSSecondCalendarUnit)
    [comps setSecond: ucal_get (_cal, UCAL_SECOND, &err)];
  if (unitFlags & NSWeekCalendarUnit)
    [comps setWeek: ucal_get (_cal, UCAL_WEEK_OF_YEAR, &err)];
  if (unitFlags & NSWeekdayCalendarUnit)
    [comps setWeekday: ucal_get (_cal, UCAL_DAY_OF_WEEK, &err)];
  if (unitFlags & NSWeekdayOrdinalCalendarUnit)
    [comps setWeekdayOrdinal: ucal_get (_cal, UCAL_WEEK_OF_MONTH, &err)];
  
  return AUTORELEASE(comps);
#else
  return nil;
#endif
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
  
  [self _resetCalendar];
  udate = (UDate)([date timeIntervalSince1970] * 1000.0);
  ucal_setMillis (_cal, udate, &err);
  
#define _ADD_COMPONENT(c, n) \
  if (opts & NSWrapCalendarComponents) \
    ucal_roll (_cal, c, n, &err); \
  else \
    ucal_add (_cal, c, n, &err);
  if ((amount = (int32_t)[comps era]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_ERA, amount);
    }
  if ((amount = (int32_t)[comps year]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_YEAR, amount);
    }
  if ((amount = (int32_t)[comps month]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_MONTH, amount);
    }
  if ((amount = (int32_t)[comps day]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_DAY_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps hour]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_HOUR_OF_DAY, amount);
    }
  if ((amount = (int32_t)[comps minute]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_MINUTE, amount);
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
  
  [self _resetCalendar];
  ucal_clear (_cal);
  
  if ((amount = (int32_t)[comps era]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_ERA, amount);
    }
  if ((amount = (int32_t)[comps year]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_YEAR, amount);
    }
  if ((amount = (int32_t)[comps month]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_MONTH, amount);
    }
  if ((amount = (int32_t)[comps day]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_DAY_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps hour]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_HOUR_OF_DAY, amount);
    }
  if ((amount = (int32_t)[comps minute]) != NSUndefinedDateComponent)
    {
      ucal_set (_cal, UCAL_MINUTE, amount);
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
  [self _setLocaleIdentifier: [self _localeIdWithLocale: locale]];
}

- (NSUInteger) firstWeekday
{
#if GS_USE_ICU == 1
  [self _resetCalendar];
  return ucal_getAttribute (_cal, UCAL_FIRST_DAY_OF_WEEK);
#else
  return 0;
#endif
}

- (void) setFirstWeekday: (NSUInteger) weekday
{
#if GS_USE_ICU == 1
  [self _resetCalendar];
  ucal_setAttribute (_cal, UCAL_FIRST_DAY_OF_WEEK, (int32_t)weekday);
#else
  return;
#endif
}

- (NSUInteger) minimumDaysInFirstWeek
{
#if GS_USE_ICU == 1
  [self _resetCalendar];
  return ucal_getAttribute (_cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK);
#else
  return 1;
#endif
}

- (void) setMinimumDaysInFirstWeek: (NSUInteger) mdw
{
#if GS_USE_ICU == 1
  [self _resetCalendar];
  ucal_setAttribute (_cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK, (int32_t)mdw);
#else
  return;
#endif
}

- (NSTimeZone *) timeZone
{
  return _tz;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  if ([tz isEqual: _tz])
    return;
  
  RELEASE(_tz);
  _tz = RETAIN(tz);
  [self _resetCalendar];
}


- (NSRange) maximumRangeOfUnit: (NSCalendarUnit) unit
{
#if GS_USE_ICU == 1
  UCalendarDateFields dateField;
  NSRange result;
  UErrorCode err = U_ZERO_ERROR;
  
  [self _resetCalendar];
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
  
  [self _resetCalendar];
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
  NSCalendar *result;

  [classLock lock];
  if (nil == autoupdatingCalendar)
    {
      autoupdatingCalendar = [[self currentCalendar] copy];
      [[NSNotificationCenter defaultCenter]
        addObserver: self
        selector: @selector(defaultsDidChange:)
        name: NSUserDefaultsDidChangeNotification
        object: nil];
    }

  result = RETAIN(autoupdatingCalendar);
  [classLock unlock];
  return AUTORELEASE(result);
}


- (BOOL) rangeOfUnit: (NSCalendarUnit) unit
           startDate: (NSDate **) datep
            interval: (NSTimeInterval *)tip
             forDate: (NSDate *)date
{
  return NO;
}

- (BOOL) isEqual: (id) obj
{
#if GS_USE_ICU == 1
  return (BOOL)ucal_equivalentTo (_cal, [obj _UCalendar]);
#else
  if ([obj isKindOfClass: [self class]])
    {
      if (![_identifier isEqual: [obj calendarIdentifier]])
        return NO;
      if (![_localeId isEqual: [obj localeIdentifier]])
        return NO;
      if (![_tz isEqual: [obj timeZone]])
        return NO;
      return YES;
    }
  
  return NO;
#endif
}

- (void) encodeWithCoder: (NSCoder*)encoder
{
  [encoder encodeObject: _identifier];
  [encoder encodeObject: _localeId];
  [encoder encodeObject: _tz];
}

- (id) initWithCoder: (NSCoder*)decoder
{
  NSString	*s = [decoder decodeObject];

  [self initWithCalendarIdentifier: s];
  [self _setLocaleIdentifier: [decoder decodeObject]];
  [self setTimeZone: [decoder decodeObject]];
  
  return self;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSCalendar *result;
  
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    {
      result = (NSCalendar *)NSCopyObject(self, 0, zone);
      result->_identifier = [_identifier copyWithZone: zone];
      result->_localeId = [_localeId copyWithZone: zone];
      result->_tz = RETAIN(_tz);
    }
  
  return result;
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
  _quarter = NSUndefinedDateComponent;
  
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
