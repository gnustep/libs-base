#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDate.h"
#import "Foundation/NSDateFormatter.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"

/* -stringForObjectValue: and -getObjectValue:forString:errorDescription:
 * are the NSFormatter entry points every cell goes through.  With the 10.4
 * behaviour they must use the ICU pattern, as -stringFromDate: does; they
 * used to format with the 10.0 calendar-format code whatever the behaviour
 * was, so a cell showed the pattern itself instead of a date.
 */
int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSDateFormatter	*formatter;
  NSDate		*date;
  NSString		*formatted;
  id			parsed = nil;
  NSString		*error = nil;

  formatter = [[NSDateFormatter alloc] init];
  [formatter setFormatterBehavior: NSDateFormatterBehavior10_4];
  [formatter setDateFormat: @"yyyy-MM-dd"];
  [formatter setTimeZone: [NSTimeZone timeZoneWithName: @"UTC"]];

  date = [NSDate dateWithTimeIntervalSinceReferenceDate: 0.0];

  formatted = [formatter stringForObjectValue: date];
  PASS_EQUAL(formatted, [formatter stringFromDate: date],
    "-stringForObjectValue: agrees with -stringFromDate: in the 10.4 behaviour");
  PASS_EQUAL(formatted, @"2001-01-01",
    "-stringForObjectValue: formats with the pattern, not with it as text");

  PASS([formatter getObjectValue: &parsed
		       forString: @"2001-01-01"
		errorDescription: &error],
    "-getObjectValue:forString:errorDescription: reads the pattern back");
  PASS_EQUAL([formatter stringFromDate: parsed], @"2001-01-01",
    "the date it read back is the date that was written");

  [formatter release];
  [arp release];
  return 0;
}
