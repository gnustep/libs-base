/*
 * growname.m - regression test for -[NSCalendarDate descriptionWithCalendarFormat:locale:].
 *
 * The internal Grow() helper, used to enlarge the output buffer while
 * formatting a date, always grew by a fixed 512 unichars.  A format field
 * whose text is longer than that increment - e.g. a long month/weekday name
 * supplied through the locale - left the buffer too small, so the following
 * -getCharacters: wrote past the end of the buffer.  Grow() now grows by at
 * least the requested size.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

int
main(int argc, char *argv[])
{
  START_SET("NSCalendarDate format buffer growth")
  NSCalendarDate	*date;
  NSString		*longName;
  NSMutableArray	*months;
  NSDictionary		*locale;
  NSString		*s;
  unsigned		i;

  /* A month name far longer than Grow()'s 512-unichar increment. */
  longName = [@"" stringByPaddingToLength: 200000
			       withString: @"X"
			      startingAtIndex: 0];
  months = [NSMutableArray arrayWithCapacity: 12];
  [months addObject: longName];		/* January */
  for (i = 1; i < 12; i++)
    {
      [months addObject: @"M"];
    }
  locale = [NSDictionary dictionaryWithObject: months
				      forKey: NSMonthNameArray];

  date = [NSCalendarDate dateWithYear: 2020 month: 1 day: 1
			         hour: 12 minute: 0 second: 0
			     timeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];

  s = [date descriptionWithCalendarFormat: @"%B" locale: locale];
  PASS([s length] == 200000,
    "a locale month name longer than the buffer increment does not overflow")

  END_SET("NSCalendarDate format buffer growth")

  return 0;
}
