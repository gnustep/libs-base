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

int
main()
{
  id a, b, c, e;                           /* dates */
  id pool;

  behavior_set_debug(0);

  pool = [[NSAutoreleasePool alloc] init];

  // NSDate tests
  printf("NSDate tests\n");
  {
    // Create NSDate instances
    a = [NSDate date];
    printf("+[date] -- %s\n", [[a description] cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 0];
    printf("+[dateWithTimeIntervalSinceNow: 0] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSinceNow: 600];
    printf("+[dateWithTimeIntervalSinceNow: 600] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSince1970: 0];
    printf("+[dateWithTimeIntervalSince1970: 0] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSince1970: -600];
    printf("+[dateWithTimeIntervalSince1970: -600] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSinceReferenceDate: 0];
    printf("+[dateWithTimeIntervalSinceReferenceDate: 0] -- %s\n", 
	   [[b description] cString]);
    b = [NSDate dateWithTimeIntervalSinceReferenceDate: 300];
    printf("+[dateWithTimeIntervalSinceReferenceDate: 300] -- %s\n", 
	   [[b description] cString]);

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
      printf("%s is earlier than %s\n", [[a description] cString],
	     [[b description] cString]);
    else
      printf("ERROR: %s is not earlier than %s\n", [[a description] cString],
	     [[b description] cString]);

    c = [a laterDate: b];
    if (c == b)
      printf("%s is later than %s\n", [[b description] cString],
	     [[a description] cString]);
    else
      printf("ERROR: %s is not later than %s\n", [[b description] cString],
	     [[a description] cString]);
  }

  // NSCalendarDate tests
  printf("NSCalendarDate tests\n");
  {
    int m, y, d, a;

    // Create an NSCalendarDate with current date and time
    c = [NSCalendarDate calendarDate];
    printf("+[calendarDate] -- %s\n", [[c description] cString]);
    printf("-[dayOfMonth] %d\n", [c dayOfMonth]);
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
    printf("calendar date %s\n", [[c description] cString]);
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
  }

  [pool release];

  exit(0);
}
