/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
#include <Foundation/NSDate.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSTimeZone.h>

#ifdef __MS_WIN32__
int _MB_init_runtime()
{
  libobjc_init_runtime();
  gnustep_base_init_runtime();
  nsdate_init_runtime();
  return 0;
}
#endif

#define DESCRIP(obj) [obj description]
#define DESCRIP_FORMAT(obj) [obj descriptionWithCalendarFormat: nil]

int
main()
{
  id a, b, c, e;                           /* dates */
  id pool;

  //behavior_set_debug(0);
  pool = [[NSAutoreleasePool alloc] init];

  NSLog(@"%@", [NSCalendarDate distantFuture]);
  NSLog(@"%@", [NSCalendarDate distantPast]);
  NSLog(@"%@", [NSCalendarDate dateWithNaturalLanguageString: @"01-08-2002 00:00:00"]);
  NSLog(@"%@", [NSCalendarDate dateWithNaturalLanguageString: @"31-08-2002 23:59:59"]);

if ([(NSDate*) [NSCalendarDate date] compare:
        [NSCalendarDate dateWithString:@"Feb 2 00:00:00 2001"
                        calendarFormat:@"%b %d %H:%M:%S %Y"]] == NSOrderedDescending) {

        NSLog(@"This version of the PostgreSQL Adaptor will expire soon.\nVisit ¬http://www.turbocat.de/ to learn how to get a new one.");
    }

  // NSDate tests
  printf("NSDate tests\n");
  {
    // Create NSDate instances
    a = [NSDate date];
    printf("+[date] -- %s\n", [DESCRIP(a) cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 0];
    printf("+[dateWithTimeIntervalSinceNow: 0] -- %s\n",
	   [DESCRIP(b) cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 600];
    printf("+[dateWithTimeIntervalSinceNow: 600] -- %s\n",
	   [DESCRIP(b) cString]);
    b = [NSDate dateWithTimeIntervalSince1970: 0];
    printf("+[dateWithTimeIntervalSince1970: 0] -- %s\n",
	   [DESCRIP(b) cString]);
    b = [NSDate dateWithTimeIntervalSince1970: -600];
    printf("+[dateWithTimeIntervalSince1970: -600] -- %s\n",
	   [DESCRIP(b) cString]);
    b = [NSDate dateWithTimeIntervalSinceReferenceDate: 0];
    printf("+[dateWithTimeIntervalSinceReferenceDate: 0] -- %s\n",
	   [DESCRIP(b) cString]);
    b = [NSDate dateWithTimeIntervalSinceReferenceDate: 300];
    printf("+[dateWithTimeIntervalSinceReferenceDate: 300] -- %s\n",
	   [DESCRIP(b) cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 24*60*40];
    printf("+[dateWithTimeIntervalSinceNow: 0] -- %s\n",
	   [DESCRIP(b) cString]);

    // Comparisons

    if ([a compare: [NSDate distantFuture]] == NSOrderedAscending)
      printf("Current date is before distantFuture\n");
    else
      printf("ERROR: Current date is *not* before distantFuture\n");

    if ([a compare: [NSDate distantPast]] == NSOrderedDescending)
      printf("Current date is after distantPast\n");
    else
      printf("ERROR: Current date is *not* after distantPast\n");

    c = [a earlierDate: b];
    if (c == a)
      printf("%s is earlier than %s\n", [DESCRIP(a) cString],
	     [DESCRIP(b) cString]);
    else
      printf("ERROR: %s is not earlier than %s\n", [DESCRIP(a) cString],
	     [DESCRIP(b) cString]);

    c = [a laterDate: b];
    if (c == b)
      printf("%s is later than %s\n", [DESCRIP(b) cString],
	     [DESCRIP(a) cString]);
    else
      printf("ERROR: %s is not later than %s\n", [DESCRIP(b) cString],
	     [DESCRIP(a) cString]);
  }

  // NSCalendarDate tests
  printf("NSCalendarDate tests\n");
  {
    NSCalendarDate	*c1;
    NSTimeZone		*gb = [NSTimeZone timeZoneWithName: @"GB"];
    int m, y, d, a;

    // Create an NSCalendarDate with current date and time
    c = [NSCalendarDate calendarDate];
    printf("+[calendarDate] -- %s\n", [DESCRIP_FORMAT(c) cString]);
    printf("-[dayOfMonth] %d\n", [c dayOfMonth]);
    printf("-[dayOfWeek] %d\n", [c dayOfWeek]);
    printf("-[dayOfYear] %d\n", [c dayOfYear]);
    printf("-[hourOfDay] %d\n", [c hourOfDay]);
    printf("-[monthOfYear] %d\n", [c monthOfYear]);
    printf("-[yearOfCommonEra] %d\n", [c yearOfCommonEra]);

    a = [c absoluteGregorianDay: 9 month: 10 year: 1996];
    printf("%d-%d-%d is Gregorian absolute %d\n", 9, 10, 1996, a);
    printf("-[dayOfCommonEra] %d\n", [c dayOfCommonEra]);
    printf("-[timeIntervalSinceReferenceDate] %f\n",
	   [c timeIntervalSinceReferenceDate]);

    a = [c absoluteGregorianDay: 1 month: 1 year: 2001];
    printf("%d-%d-%d is Gregorian absolute %d\n", 1, 1, 2001, a);
    [c gregorianDateFromAbsolute: a day: &d month: &m year: &y];
    printf("Gregorian absolute %d is %d-%d-%d\n", a, d, m, y);

    c = [NSCalendarDate dateWithString: @"1996-10-09 0:00:01"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("calendar date %s\n", [DESCRIP_FORMAT(c) cString]);
    printf("-[dayOfCommonEra] %d\n", [c dayOfCommonEra]);
    printf("-[dayOfMonth] %d\n", [c dayOfMonth]);
    printf("-[dayOfWeek] %d\n", [c dayOfWeek]);
    printf("-[dayOfYear] %d\n", [c dayOfYear]);
    printf("-[hourOfDay] %d\n", [c hourOfDay]);
    printf("-[minuteOfHour] %d\n", [c minuteOfHour]);
    printf("-[monthOfYear] %d\n", [c monthOfYear]);
    printf("-[secondOfMinute] %d\n", [c secondOfMinute]);
    printf("-[yearOfCommonEra] %d\n", [c yearOfCommonEra]);
    printf("-[timeIntervalSinceReferenceDate] %f\n",
	   [c timeIntervalSinceReferenceDate]);
    e = [NSCalendarDate dateWithString: @"1996-10-09 0:00:0"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("calendar date %s\n", [[e description] cString]);
    printf("-[timeIntervalSinceReferenceDate] %f\n",
	   [e timeIntervalSinceReferenceDate]);
    printf("NSCalendrical time tests\n");
    {
      NSCalendarDate *momsBDay = [NSCalendarDate dateWithYear:1936
	month:1 day:8 hour:7 minute:30 second:0
	timeZone:[NSTimeZone timeZoneWithName:@"EST"]];
      NSCalendarDate *dob = [NSCalendarDate dateWithYear:1965
	month:12 day:7 hour:17 minute:25 second:0
	timeZone:[NSTimeZone timeZoneWithName:@"EST"]];
      int	years, months, days;

      [dob years:&years months:&months days:&days hours:0
		minutes:0 seconds:0 sinceDate:momsBDay];
      printf("%d, %d, %d\n", years, months, days);
      [dob years:0 months:&months days:&days hours:0
		minutes:0 seconds:0 sinceDate:momsBDay];
      printf("%d, %d\n", months, days);
    }

    printf("\nY2K checks\n");
    c = [NSCalendarDate dateWithString: @"1999-12-31 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [DESCRIP_FORMAT(c) cString]);
    printf("YYYY-MM-DD %d-%d-%d\n", [c yearOfCommonEra], [c monthOfYear], [c dayOfMonth]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [DESCRIP_FORMAT(c) cString]);

    printf("\nY2K is a leap year checks\n");
    c = [NSCalendarDate dateWithString: @"2000-2-28 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:5 minute:0 second:0];
    printf("Add five hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:1 month:0 day:0 hour:0 minute:0 second:0];
    printf("Add one year - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:-1 hour:0 minute:0 second:0];
    printf("Subtract one day - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:1 month:0 day:1 hour:0 minute:0 second:0];
    printf("Add a year and a day - %s\n", [DESCRIP_FORMAT(c) cString]);

    printf("\n2004 is a leap year checks\n");
    c = [NSCalendarDate dateWithString: @"2004-2-28 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [DESCRIP_FORMAT(c) cString]);

    printf("\n2100 is NOT a leap year checks\n");
    c = [NSCalendarDate dateWithString: @"2100-2-28 23:59:59"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add one second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:0 minute:0 second:1];
    printf("Add another second - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [DESCRIP_FORMAT(c) cString]);

    c = [NSCalendarDate dateWithString: @"2002-03-31 00:30:00 GB"
			calendarFormat: @"%Y-%m-%d %H:%M:%S %Z"];
    printf("\nSavings time begins at %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-1 minute:0 second:0];
    printf("Subtract an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:2 minute:0 second:0];
    printf("Add two hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:3 minute:0 second:0];
    printf("Add three hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-4 minute:0 second:0];
    printf("Subtract four hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:3 minute:0 second:0];
    printf("Add three hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-4 minute:0 second:0];
    printf("Subtract four hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:4 minute:0 second:0];
    printf("Add four hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-24 minute:0 second:0];
    printf("Subtract twentyfour hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:24 minute:0 second:0];
    printf("Add twentyfour hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:-1 hour:0 minute:0 second:0];
    printf("Subtract a day - %s\n", [DESCRIP_FORMAT(c) cString]);

    c = [NSCalendarDate dateWithString: @"2002-10-27 00:30:00 GB"
			calendarFormat: @"%Y-%m-%d %H:%M:%S %Z"];
    printf("\nSavings time ends at %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:1 minute:0 second:0];
    printf("Add an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-1 minute:0 second:0];
    printf("Subtract an hour - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:2 minute:0 second:0];
    printf("Add two hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-2 minute:0 second:0];
    printf("Subtract two hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:3 minute:0 second:0];
    printf("Add three hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-4 minute:0 second:0];
    printf("Subtract four hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:3 minute:0 second:0];
    printf("Add three hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-4 minute:0 second:0];
    printf("Subtract four hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:4 minute:0 second:0];
    printf("Add four hours - %s\n", [DESCRIP_FORMAT(c) cString]);
    c = [c addYear:0 month:0 day:0 hour:-24 minute:0 second:0];
    printf("Subtract twentyfour hours - %s\n", [DESCRIP_FORMAT(c) cString]);

    c = [NSCalendarDate dateWithYear: 2002 month: 3 day: 31 hour: 1 minute: 30 second: 0 timeZone: gb];
    printf("Build at %s\n", [[c description] cString]);

    c = [NSCalendarDate dateWithString: @"2002-09-27 01:59:00"
			calendarFormat: @"%Y-%m-%d %H:%M:%S"];
    printf("Start at %s\n", [DESCRIP_FORMAT(c) cString]);
    c1 = [c dateByAddingYears: 0
		       months: 0
			 days: -180
		        hours: 0
		      minutes: 0
		      seconds: 0];
    printf("Subtract 180 %s\n", [DESCRIP_FORMAT(c1) cString]);

    printf("Week of year tests ... ");
    if ([[NSCalendarDate dateWithYear: 2002 month: 12 day: 29 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 52)
      printf("Failed on 2002/12/29 is week 52\n");
    if ([[NSCalendarDate dateWithYear: 2002 month: 12 day: 30 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2002/12/30 is week 1\n");
    if ([[NSCalendarDate dateWithYear: 2002 month: 12 day: 31 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2002/12/31 is week 1\n");
    if ([[NSCalendarDate dateWithYear: 2003 month: 1 day: 1 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2003/01/01 is week 1\n");
    else if ([[NSCalendarDate dateWithYear: 2003 month: 1 day: 2 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2003/01/02 is week 1\n");
    else if ([[NSCalendarDate dateWithYear: 2003 month: 1 day: 3 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2003/01/03 is week 1\n");
    else if ([[NSCalendarDate dateWithYear: 2003 month: 1 day: 4 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2003/01/04 is week 1\n");
    else if ([[NSCalendarDate dateWithYear: 2003 month: 1 day: 5 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 1)
      printf("Failed on 2003/01/05 is week 1\n");
    else if ([[NSCalendarDate dateWithYear: 2003 month: 1 day: 6 hour: 0
      minute: 0 second: 0 timeZone: gb] weekOfYear] != 2)
      printf("Failed on 2003/01/06 is week 2\n");
    else
      printf("All passed\n");


    c = [NSCalendarDate dateWithString: @"2004-05-30 00:30:00 HPT"
			calendarFormat: @"%Y-%m-%d %H:%M:%S %Z"];
    c1 = [NSCalendarDate dateWithString: @"2004-05-30 00:30:00 HST"
			calendarFormat: @"%Y-%m-%d %H:%M:%S %Z"];
    printf("date with time zone abbr %s\n", [[c description] cString]);
    if ([c isEqual: c1])
      printf("Passed date with time zone abbreviation\n");
    else
      printf("Failed date with time zone abbreviation\n");

  }

  [pool release];

  exit(0);
}
