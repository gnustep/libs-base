#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/NSCalendar.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSDateFormatter.h>
#include <stdio.h>

#if	defined(GS_USE_ICU)
#define	NSCALENDAR_SUPPORTED	GS_USE_ICU
#else
#define	NSCALENDAR_SUPPORTED	1 /* Assume Apple support */
#endif

int main()
{
  NSDateComponents *comps;
  NSCalendar *cal;
  NSDate *date;
  NSDate *date2;
  
  START_SET("NSCalendar date component differences")
  if (!NSCALENDAR_SUPPORTED)
    SKIP("NSCalendar not supported\nThe ICU library was not available when GNUstep-base was built")
  
  cal = [[NSCalendar alloc] initWithCalendarIdentifier: NSGregorianCalendar];
  [cal setFirstWeekday: 1];
  
  date = [NSDate dateWithString: @"2015-01-01 01:01:01 +0100"];
  date2 = [NSDate dateWithString: @"2015-02-03 04:05:06 +0100"];

  comps = [cal components:
    NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit
    | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit
                 fromDate: date
                   toDate: date2
                  options: 0];
  if (nil == comps)
    {
      SKIP("-components:fromDate:toDate:options: not implementaed. The ICU library was not available (or too old) when GNUstep-base was built")
    }
  PASS([comps year] == 0, "year difference correct");
  PASS([comps month] == 1, "month difference correct");
  PASS([comps day] == 2, "day difference correct");
  PASS([comps hour] == 3, "hour difference correct");
  PASS([comps minute] == 4, "minute difference correct");
  PASS([comps second] == 5, "second difference correct");
  
  comps = [cal components: NSDayCalendarUnit
                 fromDate: date
                   toDate: date2
                  options: 0];
  PASS([comps month] == NSNotFound, "no month returned if not requested");
  PASS([comps day] == 33, "day difference without larger unit correct");

  
  /* Test getEra:year:month:day:fromDate:
   */
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat: @"d MMM yyyy HH:mm:ss Z"];
  NSDate *date = [dateFormatter dateFromString:@"22 Nov 1969 08:15:00 Z"];

  NSInteger era = 0;
  NSInteger year = 0;
  NSInteger month = 0;
  NSInteger day = 0;
  NSInteger hour = 0;
  NSInteger min = 0;
  NSInteger sec = 0;
  NSInteger nano = 0;
  
  [cal getEra:&era year:&year month:&month day:&day fromDate:date];

  PASS(era == 1, "getEra:year:month:day:fromDate: returns correct era");
  PASS(year == 1969, "getEra:year:month:day:fromDate: returns correct year");
  PASS(month == 11, "getEra:year:month:day:fromDate: returns correct month");
  PASS(day == 22, "getEra:year:month:day:fromDate: returns correct day");
  
  /* Test getHour:minute:second:nanosecond:fromDate:
   */
  [cal getHour:&hour minute:&min second:&sec nanosecond:&nano fromDate:date];

  PASS(hour == 3, "getHour:minute:second:nanosecond:fromDate: returns correct hour");
  PASS(min == 15, "getHour:minute:second:nanosecond:fromDate: returns correct minute");
  PASS(sec == 0, "getHour:minute:second:nanosecond:fromDate: returns correct second");
  PASS(nano == 0, "getHour:minute:second:nanosecond:fromDate: returns correct nanosecond");
  
  RELEASE(dateFormatter);
  RELEASE(cal);
  
  END_SET("NSCalendar date component differences")
  return 0;
}
