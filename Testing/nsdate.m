#include <Foundation/NSDate.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>

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
    printf("\nSavings time checks at %s\n", [DESCRIP_FORMAT(c) cString]);
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

  }

  [pool release];

  exit(0);
}
