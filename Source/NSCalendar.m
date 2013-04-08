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
#import "Foundation/NSException.h"
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
  if (unit & NSQuarterCalendarUnit)
    return (UCAL_MONTH + 2) / 3;
  return -1;
}
#endif /* GS_USE_ICU */

typedef struct {
  NSString      *identifier;
  NSString      *localeID;
  NSTimeZone    *tz; 
  void          *cal;
  NSInteger     firstWeekday;
  NSInteger     minimumDaysInFirstWeek;
} Calendar; 
#define my ((Calendar*)_NSCalendarInternal)
#define aac ((Calendar*)(autoupdatingCalendar->_NSCalendarInternal))

@interface NSCalendar (PrivateMethods)
- (void) _resetCalendar;
- (void *) _UCalendar;
- (NSString *) _localeIDWithLocale: (NSLocale*)locale;
- (NSString *) _localeIDentifier;
- (void) _setLocaleIdentifier: (NSString*)identifier;
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
  
  if (my->cal != NULL)
    ucal_close (my->cal);
  
  cLocaleId = [my->localeID UTF8String];
  tzName = [my->tz name];
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
  my->cal = 
    ucal_open ((const UChar *)cTzId, tzLen, cLocaleId, UCAL_DEFAULT, &err);

  if (NSNotFound == my->firstWeekday)
    {
      my->firstWeekday
        = ucal_getAttribute(my->cal, UCAL_FIRST_DAY_OF_WEEK);
    }
  else
    {
      ucal_setAttribute(my->cal, UCAL_FIRST_DAY_OF_WEEK,
        (int32_t)my->firstWeekday);
    }

  if (NSNotFound == my->minimumDaysInFirstWeek)
    {
      my->minimumDaysInFirstWeek
        = ucal_getAttribute(my->cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK);
    }
  else
    {
      ucal_setAttribute(my->cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK,
        (int32_t)my->minimumDaysInFirstWeek);
    }

#endif
}

- (void *) _UCalendar
{
  return my->cal;
}

- (NSString*) _localeIDWithLocale: (NSLocale *)locale
{
  NSString *result;
  NSString *localeId;
  NSMutableDictionary *tmpDict;
  
  localeId = [locale localeIdentifier];
  tmpDict = [[NSLocale componentsFromLocaleIdentifier: localeId]
    mutableCopyWithZone: NULL];
  [tmpDict setObject: my->identifier forKey: NSLocaleCalendarIdentifier];
  result = [NSLocale localeIdentifierFromComponents: tmpDict];
  RELEASE(tmpDict);
  
  return result;
}

- (NSString*) _localeIDentifier
{
  return my->localeID;
}

- (void) _setLocaleIdentifier: (NSString *) identifier
{
  if ([identifier isEqualToString: my->localeID])
    return;
  
  RELEASE(my->localeID);
  my->localeID = RETAIN(identifier);
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
  
  if ([locale isEqual: aac->localeID] == NO
    || [calendar isEqual: aac->identifier] == NO
    || [tz isEqual: [(aac->tz) name]] == NO)
    {
      [classLock lock];
      RELEASE(aac->localeID);
      RELEASE(aac->identifier);
      RELEASE(aac->tz);
#if GS_USE_ICU == 1
      ucal_close(aac->cal);
#endif
      
      aac->localeID = RETAIN(locale);
      aac->identifier = RETAIN(calendar);
      aac->tz = [[NSTimeZone alloc] initWithName: tz];
      
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

- (id) init
{
  self = [self initWithCalendarIdentifier: nil];
  return self;
}

- (id) initWithCalendarIdentifier: (NSString *) string
{
  NSAssert(0 == _NSCalendarInternal, NSInvalidArgumentException);
  _NSCalendarInternal = 
#if     GS_WITH_GC
    NSAllocateCollectable(sizeof(Calendar), NSScannedOption);
#else
    NSZoneCalloc([self zone], sizeof(Calendar), 1);
#endif

  my->firstWeekday = NSNotFound;
  my->minimumDaysInFirstWeek = NSNotFound;

  if ([string isEqualToString: NSGregorianCalendar])
    my->identifier = NSGregorianCalendar;
  else if ([string isEqualToString: NSBuddhistCalendar])
    my->identifier = NSBuddhistCalendar;
  else if ([string isEqualToString: NSChineseCalendar])
    my->identifier = NSChineseCalendar;
  else if ([string isEqualToString: NSHebrewCalendar])
    my->identifier = NSHebrewCalendar;
  else if ([string isEqualToString: NSIslamicCalendar])
    my->identifier = NSIslamicCalendar;
  else if ([string isEqualToString: NSIslamicCivilCalendar])
    my->identifier = NSIslamicCivilCalendar;
  else if ([string isEqualToString: NSJapaneseCalendar])
    my->identifier = NSJapaneseCalendar;
  else if ([string isEqualToString: NSRepublicOfChinaCalendar])
    my->identifier = NSRepublicOfChinaCalendar;
  else if ([string isEqualToString: NSPersianCalendar])
    my->identifier = NSPersianCalendar;
  else if ([string isEqualToString: NSIndianCalendar])
    my->identifier = NSIndianCalendar;
  else if ([string isEqualToString: NSISO8601Calendar])
    my->identifier = NSISO8601Calendar;
  else
    {
      RELEASE(self);
      return nil;
    }
  
  // It's much easier to keep a copy of the NSLocale's string representation
  // than to have to build it everytime we have to open a UCalendar.
  my->localeID = RETAIN([self _localeIDWithLocale: [NSLocale currentLocale]]);
  my->tz = RETAIN([NSTimeZone defaultTimeZone]);
  
  [self _resetCalendar];
  return self;
}

- (void) dealloc
{
  if (0 != _NSCalendarInternal)
    {
#if GS_USE_ICU == 1
      ucal_close (my->cal);
#endif
      RELEASE(my->identifier);
      RELEASE(my->localeID);
      RELEASE(my->tz);
      NSZoneFree([self zone], _NSCalendarInternal);
    }
  [super dealloc];
}

- (NSString *) calendarIdentifier
{
  return my->identifier;
}


- (NSDateComponents *) components: (NSUInteger) unitFlags
                         fromDate: (NSDate *) date
{
#if GS_USE_ICU == 1
  NSDateComponents *comps;
  UErrorCode err = U_ZERO_ERROR;
  UDate udate;
  
  udate = (UDate)floor([date timeIntervalSince1970] * 1000.0);
  ucal_setMillis (my->cal, udate, &err);
  if (U_FAILURE(err))
    return nil;
  
  comps = [[NSDateComponents alloc] init];
  if (unitFlags & NSEraCalendarUnit)
    [comps setEra: ucal_get (my->cal, UCAL_ERA, &err)];
  if (unitFlags & NSYearCalendarUnit)
    [comps setYear: ucal_get (my->cal, UCAL_YEAR, &err)];
  if (unitFlags & NSMonthCalendarUnit)
    [comps setMonth: ucal_get (my->cal, UCAL_MONTH, &err)+1];
  if (unitFlags & NSDayCalendarUnit)
    [comps setDay: ucal_get (my->cal, UCAL_DAY_OF_MONTH, &err)];
  if (unitFlags & NSHourCalendarUnit)
    [comps setHour: ucal_get (my->cal, UCAL_HOUR_OF_DAY, &err)];
  if (unitFlags & NSMinuteCalendarUnit)
    [comps setMinute: ucal_get (my->cal, UCAL_MINUTE, &err)];
  if (unitFlags & NSSecondCalendarUnit)
    [comps setSecond: ucal_get (my->cal, UCAL_SECOND, &err)];
  if (unitFlags & (NSWeekCalendarUnit|NSWeekOfYearCalendarUnit))
    [comps setWeek: ucal_get (my->cal, UCAL_WEEK_OF_YEAR, &err)];
  if (unitFlags & NSWeekdayCalendarUnit)
    [comps setWeekday: ucal_get (my->cal, UCAL_DAY_OF_WEEK, &err)];
  if (unitFlags & NSWeekdayOrdinalCalendarUnit)
    [comps setWeekdayOrdinal: ucal_get (my->cal, UCAL_DAY_OF_WEEK_IN_MONTH, &err)];
  if (unitFlags & NSWeekOfMonthCalendarUnit)
    [comps setWeekOfMonth: ucal_get (my->cal, UCAL_WEEK_OF_MONTH, &err)];
  if (unitFlags & NSYearForWeekOfYearCalendarUnit)
    [comps setYearForWeekOfYear: ucal_get (my->cal, UCAL_YEAR_WOY, &err)];
  
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
  ucal_setMillis (my->cal, udate, &err);
  
#define _ADD_COMPONENT(c, n) \
  if (opts & NSWrapCalendarComponents) \
    ucal_roll (my->cal, c, n, &err); \
  else \
    ucal_add (my->cal, c, n, &err);
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
  if ((amount = (int32_t)[comps weekOfMonth]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_WEEK_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps yearForWeekOfYear]) != NSUndefinedDateComponent)
    {
      _ADD_COMPONENT(UCAL_YEAR_WOY, amount);
    }
#undef _ADD_COMPONENT
  
  udate = ucal_getMillis (my->cal, &err);
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
  ucal_clear (my->cal);
  
  if ((amount = (int32_t)[comps era]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_ERA, amount);
    }
  if ((amount = (int32_t)[comps year]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_YEAR, amount);
    }
  if ((amount = (int32_t)[comps month]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_MONTH, amount-1);
    }
  if ((amount = (int32_t)[comps day]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_DAY_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps hour]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_HOUR_OF_DAY, amount);
    }
  if ((amount = (int32_t)[comps minute]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_MINUTE, amount);
    }
  if ((amount = (int32_t)[comps second]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_SECOND, amount);
    }
  if ((amount = (int32_t)[comps week]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_WEEK_OF_YEAR, amount);
    }
  if ((amount = (int32_t)[comps weekday]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_DAY_OF_WEEK, amount);
    }
  if ((amount = (int32_t)[comps weekOfMonth]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_WEEK_OF_MONTH, amount);
    }
  if ((amount = (int32_t)[comps yearForWeekOfYear]) != NSUndefinedDateComponent)
    {
      ucal_set (my->cal, UCAL_YEAR_WOY, amount);
    }
  
  udate = ucal_getMillis (my->cal, &err);
  if (U_FAILURE(err))
    return nil;
  
  return [NSDate dateWithTimeIntervalSince1970: (udate / 1000.0)];
#else
  return nil;
#endif
}

- (NSLocale *) locale
{
  return AUTORELEASE([[NSLocale alloc] initWithLocaleIdentifier: my->localeID]);
}

- (void) setLocale: (NSLocale *) locale
{
  [self _setLocaleIdentifier: [self _localeIDWithLocale: locale]];
}

- (NSUInteger) firstWeekday
{
  return my->firstWeekday;
}

- (void) setFirstWeekday: (NSUInteger)weekday
{
  my->firstWeekday = weekday;
#if GS_USE_ICU == 1
  ucal_setAttribute (my->cal, UCAL_FIRST_DAY_OF_WEEK, my->firstWeekday);
#endif
}

- (NSUInteger) minimumDaysInFirstWeek
{
  return my->minimumDaysInFirstWeek;
}

- (void) setMinimumDaysInFirstWeek: (NSUInteger)mdw
{
  my->minimumDaysInFirstWeek = (int32_t)mdw;
#if GS_USE_ICU == 1
  ucal_setAttribute (my->cal, UCAL_MINIMAL_DAYS_IN_FIRST_WEEK,
    my->minimumDaysInFirstWeek);
#endif
}

- (NSTimeZone *) timeZone
{
  return my->tz;
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  if ([tz isEqual: my->tz])
    return;
  
  RELEASE(my->tz);
  my->tz = RETAIN(tz);
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
    (NSUInteger)ucal_getLimit (my->cal, dateField, UCAL_MINIMUM, &err);
  result.length = 
    (NSUInteger)ucal_getLimit (my->cal, dateField, UCAL_MAXIMUM, &err)
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
    (NSUInteger)ucal_getLimit (my->cal, dateField, UCAL_GREATEST_MINIMUM, &err);
  result.length = 
    (NSUInteger)ucal_getLimit (my->cal, dateField, UCAL_LEAST_MAXIMUM, &err)
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
  return (BOOL)ucal_equivalentTo (my->cal, [obj _UCalendar]);
#else
  if ([obj isKindOfClass: [self class]])
    {
      if (![my->identifier isEqual: [obj calendarIdentifier]])
        return NO;
      if (![my->localeID isEqual: [obj localeIdentifier]])
        return NO;
      if (![my->tz isEqual: [obj timeZone]])
        return NO;
      return YES;
    }
  
  return NO;
#endif
}

- (void) encodeWithCoder: (NSCoder*)encoder
{
  [encoder encodeObject: my->identifier];
  [encoder encodeObject: my->localeID];
  [encoder encodeObject: my->tz];
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
    {
      return RETAIN(self);
    }
  else
    {
      result = [[[self class] allocWithZone: zone]
        initWithCalendarIdentifier: my->identifier];
      [result _setLocaleIdentifier: my->localeID];
      [result setTimeZone: my->tz];
    }
  
  return result;
}

@end

#undef  my


@implementation NSDateComponents

typedef struct {
  NSInteger era;
  NSInteger year;
  NSInteger month;
  NSInteger day;
  NSInteger hour;
  NSInteger minute;
  NSInteger second;
  NSInteger week;
  NSInteger weekday;
  NSInteger weekdayOrdinal;
  NSInteger quarter;
  NSInteger weekOfMonth;
  NSInteger yearForWeekOfYear;
  NSCalendar *cal;
  NSTimeZone *tz;
} DateComp;

#define my ((DateComp*)_NSDateComponentsInternal)

- (void) dealloc
{
  if (0 != _NSDateComponentsInternal)
    {
      RELEASE(my->cal);
      RELEASE(my->tz);
      NSZoneFree([self zone], _NSDateComponentsInternal);
    }
  [super dealloc];
}

- (id) init
{
  if (nil != (self = [super init]))
    {
      _NSDateComponentsInternal = 
#if     GS_WITH_GC
      NSAllocateCollectable(sizeof(DateComp), NSScannedOption);
#else
      NSZoneCalloc([self zone], sizeof(DateComp), 1);
#endif

      my->era = NSUndefinedDateComponent;
      my->year = NSUndefinedDateComponent;
      my->month = NSUndefinedDateComponent;
      my->day = NSUndefinedDateComponent;
      my->hour = NSUndefinedDateComponent;
      my->minute = NSUndefinedDateComponent;
      my->second = NSUndefinedDateComponent;
      my->week = NSUndefinedDateComponent;
      my->weekday = NSUndefinedDateComponent;
      my->weekdayOrdinal = NSUndefinedDateComponent;
      my->quarter = NSUndefinedDateComponent;
      my->weekOfMonth = NSUndefinedDateComponent;
      my->yearForWeekOfYear = NSUndefinedDateComponent;
      my->cal = NULL;
      my->tz = NULL;
     } 
  return self;
}

- (NSInteger) day
{
  return my->day;
}

- (NSInteger) era
{
  return my->era;
}

- (NSInteger) hour
{
  return my->hour;
}

- (NSInteger) minute
{
  return my->minute;
}

- (NSInteger) month
{
  return my->month;
}

- (NSInteger) quarter
{
  return my->quarter;
}

- (NSInteger) second
{
  return my->second;
}

- (NSInteger) week
{
  return my->week;
}

- (NSInteger) weekday
{
  return my->weekday;
}

- (NSInteger) weekdayOrdinal
{
  return my->weekdayOrdinal;
}

- (NSInteger) year
{
  return my->year;
}

- (NSInteger) weekOfMonth
{
  return my->weekOfMonth;
}

- (NSInteger) weekOfYear
{
  return my->week;
}

- (NSInteger) yearForWeekOfYear
{
  return my->yearForWeekOfYear;
}

- (NSCalendar *) calendar
{
  return my->cal;
}

- (NSTimeZone *) timeZone
{
  return my->tz;
}

- (NSDate *) date
{
  NSCalendar* cal = [self calendar];
  NSTimeZone* zone = [self timeZone];

  if (zone != NULL)
    [cal setTimeZone: zone];

  return [cal dateFromComponents: self];
}


- (void) setDay: (NSInteger) v
{
  my->day = v;
}

- (void) setEra: (NSInteger) v
{
  my->era = v;
}

- (void) setHour: (NSInteger) v
{
  my->hour = v;
}

- (void) setMinute: (NSInteger) v
{
  my->minute = v;
}

- (void) setMonth: (NSInteger) v
{
  my->month = v;
}

- (void) setQuarter: (NSInteger) v
{
  my->quarter = v;
}

- (void) setSecond: (NSInteger) v
{
  my->second = v;
}

- (void) setWeek: (NSInteger) v
{
  my->week = v;
}

- (void) setWeekday: (NSInteger) v
{
  my->weekday = v;
}

- (void) setWeekdayOrdinal: (NSInteger) v
{
  my->weekdayOrdinal = v;
}

- (void) setYear: (NSInteger) v
{
  my->year = v;
}

- (void) setWeekOfYear: (NSInteger) v
{
  my->week = v;
}

- (void) setWeekOfMonth: (NSInteger) v
{
  my->weekOfMonth = v;
}

- (void) setYearForWeekOfYear: (NSInteger) v
{
  my->yearForWeekOfYear = v;
}

- (void) setCalendar: (NSCalendar *) cal
{
  ASSIGN(my->cal, cal);
}

- (void) setTimeZone: (NSTimeZone *) tz
{
  ASSIGN(my->tz, tz);
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return RETAIN(self);
    }
  else
    {
      NSDateComponents  *c = [[NSDateComponents allocWithZone: zone] init];
      
      memcpy(c->_NSDateComponentsInternal, _NSDateComponentsInternal,
        sizeof(DateComp));
      /* We gave objects to the copy, so we need to retain them too.
       */
      RETAIN(my->cal);
      RETAIN(my->tz);
      return c;
    }
}

@end
