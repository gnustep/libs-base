/*
 * rangeOfUnitInterval.m - -[NSCalendar rangeOfUnit:startDate:interval:forDate:]
 * returns the start and duration of the calendar unit that contains the date,
 * which was previously an unimplemented stub that always returned NO.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

#if	defined(GS_USE_ICU)
#define	NSCALENDAR_SUPPORTED	GS_USE_ICU
#else
#define	NSCALENDAR_SUPPORTED	1 /* Assume Apple support */
#endif

static NSCalendar	*gcal;

static NSDate *
mkdate(int y, int mo, int d, int h, int mi, int s)
{
  NSDateComponents	*c = [[NSDateComponents new] autorelease];

  [c setYear: y];
  [c setMonth: mo];
  [c setDay: d];
  [c setHour: h];
  [c setMinute: mi];
  [c setSecond: s];
  return [gcal dateFromComponents: c];
}

static BOOL
chk(NSCalendarUnit unit, NSDate *date, NSDate *expStart, NSTimeInterval expLen)
{
  NSDate		*start = nil;
  NSTimeInterval	len = 0;

  return [gcal rangeOfUnit: unit startDate: &start interval: &len forDate: date]
    && [start isEqualToDate: expStart]
    && len == expLen;
}

int main(void)
{
  START_SET("NSCalendar rangeOfUnit:startDate:interval:forDate:")
    NSDate	*d;

    if (NSCALENDAR_SUPPORTED == 0)
      {
        SKIP("NSCalendar not supported (no ICU)")
      }

    gcal = [[NSCalendar alloc]
      initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
    [gcal setTimeZone: [NSTimeZone timeZoneWithName: @"UTC"]];
    [gcal setFirstWeekday: 1];
    [gcal setMinimumDaysInFirstWeek: 1];

    d = mkdate(2015, 2, 18, 12, 30, 45);	// a Wednesday

    PASS(chk(NSCalendarUnitYear, d, mkdate(2015, 1, 1, 0, 0, 0), 31536000.0),
      "the year containing the date starts on 1 January");
    PASS(chk(NSCalendarUnitMonth, d, mkdate(2015, 2, 1, 0, 0, 0), 2419200.0),
      "the month containing the date is 28 days");
    PASS(chk(NSCalendarUnitDay, d, mkdate(2015, 2, 18, 0, 0, 0), 86400.0),
      "the day containing the date starts at midnight");
    PASS(chk(NSCalendarUnitHour, d, mkdate(2015, 2, 18, 12, 0, 0), 3600.0),
      "the hour containing the date");
    PASS(chk(NSCalendarUnitMinute, d, mkdate(2015, 2, 18, 12, 30, 0), 60.0),
      "the minute containing the date");
    PASS(chk(NSCalendarUnitSecond, d, mkdate(2015, 2, 18, 12, 30, 45), 1.0),
      "the second containing the date");
    PASS(chk(NSCalendarUnitWeekOfYear, d, mkdate(2015, 2, 15, 0, 0, 0), 604800.0),
      "the week containing the date starts on the first weekday and is 7 days");

    {
      NSDate		*s = nil;
      NSTimeInterval	l = 0;

      PASS([gcal rangeOfUnit: NSCalendarUnitEra
                   startDate: &s interval: &l forDate: d] == NO,
        "an unhandled unit returns NO");
    }
  END_SET("NSCalendar rangeOfUnit:startDate:interval:forDate:")

  return 0;
}
