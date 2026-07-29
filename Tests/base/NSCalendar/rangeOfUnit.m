/*
 * rangeOfUnit.m - -[NSCalendar rangeOfUnit:inUnit:forDate:] returns the range
 * of the smaller unit within the larger unit for the given date (e.g. the
 * number of days in the month), which was previously an unimplemented stub
 * that always returned {0, 0}.
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
mkdate(int y, int mo, int d)
{
  NSDateComponents	*c = [[NSDateComponents new] autorelease];

  [c setYear: y];
  [c setMonth: mo];
  [c setDay: d];
  return [gcal dateFromComponents: c];
}

#define	RNG(sm, lg, dt)	[gcal rangeOfUnit: (sm) inUnit: (lg) forDate: (dt)]

int main(void)
{
  START_SET("NSCalendar rangeOfUnit:inUnit:forDate:")
    NSRange	r;

    if (NSCALENDAR_SUPPORTED == 0)
      {
        SKIP("NSCalendar not supported (no ICU)")
      }

    gcal = [[NSCalendar alloc]
      initWithCalendarIdentifier: NSCalendarIdentifierGregorian];
    [gcal setTimeZone: [NSTimeZone timeZoneWithName: @"UTC"]];
    /* Fix the week definition so the week counts are deterministic. */
    [gcal setFirstWeekday: 1];
    [gcal setMinimumDaysInFirstWeek: 1];

    r = RNG(NSCalendarUnitDay, NSCalendarUnitMonth, mkdate(2015, 2, 15));
    PASS(r.location == 1 && r.length == 28, "February 2015 has 28 days");
    r = RNG(NSCalendarUnitDay, NSCalendarUnitMonth, mkdate(2016, 2, 15));
    PASS(r.location == 1 && r.length == 29, "February 2016 (leap) has 29 days");
    r = RNG(NSCalendarUnitDay, NSCalendarUnitMonth, mkdate(2015, 1, 15));
    PASS(r.location == 1 && r.length == 31, "January has 31 days");
    r = RNG(NSCalendarUnitDay, NSCalendarUnitMonth, mkdate(2015, 4, 15));
    PASS(r.location == 1 && r.length == 30, "April has 30 days");

    r = RNG(NSCalendarUnitDay, NSCalendarUnitYear, mkdate(2015, 6, 1));
    PASS(r.location == 1 && r.length == 365, "2015 has 365 days");
    r = RNG(NSCalendarUnitDay, NSCalendarUnitYear, mkdate(2016, 6, 1));
    PASS(r.location == 1 && r.length == 366, "2016 (leap) has 366 days");

    r = RNG(NSCalendarUnitMonth, NSCalendarUnitYear, mkdate(2015, 6, 1));
    PASS(r.location == 1 && r.length == 12, "a year has 12 months");

    r = RNG(NSCalendarUnitHour, NSCalendarUnitDay, mkdate(2015, 6, 1));
    PASS(r.location == 0 && r.length == 24, "a day has 24 hours");
    r = RNG(NSCalendarUnitMinute, NSCalendarUnitHour, mkdate(2015, 6, 1));
    PASS(r.location == 0 && r.length == 60, "an hour has 60 minutes");
    r = RNG(NSCalendarUnitSecond, NSCalendarUnitMinute, mkdate(2015, 6, 1));
    PASS(r.location == 0 && r.length == 60, "a minute has 60 seconds");

    r = RNG(NSCalendarUnitWeekday, NSCalendarUnitWeekOfYear, mkdate(2015, 6, 1));
    PASS(r.location == 1 && r.length == 7, "a week has 7 weekdays");
    r = RNG(NSCalendarUnitWeekOfMonth, NSCalendarUnitMonth, mkdate(2015, 2, 15));
    PASS(r.location == 1 && r.length == 4, "February 2015 spans 4 weeks");
    r = RNG(NSCalendarUnitWeekOfYear, NSCalendarUnitYear, mkdate(2015, 6, 1));
    PASS(r.location == 1 && r.length >= 52 && r.length <= 54,
      "2015 spans a full year of week-of-year values");

    /* A pair that is not a containment yields {NSNotFound, NSNotFound}. */
    r = RNG(NSCalendarUnitMonth, NSCalendarUnitDay, mkdate(2015, 6, 1));
    PASS(r.location == NSNotFound, "a month is not contained in a day");
  END_SET("NSCalendar rangeOfUnit:inUnit:forDate:")

  return 0;
}
