#import <Foundation/NSDate.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>
#import "Testing.h"

int main(void)
{
  NSDateFormatter *formatter;
  NSDate *date;

  START_SET("NSDateFormatter object formatting")

  formatter = [NSDateFormatter new];
  date = [NSDate dateWithTimeIntervalSinceReferenceDate: 0];

  PASS([formatter stringForObjectValue: nil] == nil,
    "nil is not formatted as a date")
  PASS([formatter stringForObjectValue: @"2001-01-01"] == nil,
    "objects other than dates are rejected")

#if !defined(GS_USE_ICU) || GS_USE_ICU == 1
  [formatter setLocale:
    [NSLocale localeWithLocaleIdentifier: @"en_US_POSIX"]];
  [formatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: -18000]];
  [formatter setDateFormat: @"yyyy-MM-dd 'at' HH:mm"];

  /* NSCell uses the NSFormatter entry point to display its object value.
   * It must use the same pattern, locale and time zone as stringFromDate:.
   */
  PASS_EQUAL([formatter stringForObjectValue: date], @"2000-12-31 at 19:00",
    "object formatting uses the modern pattern and formatter time zone")
  PASS_EQUAL([formatter editingStringForObjectValue: date],
    @"2000-12-31 at 19:00",
    "editing uses the same date formatting as display")

  [formatter setLocale:
    [NSLocale localeWithLocaleIdentifier: @"fr_FR"]];
  [formatter setDateFormat: @"d MMMM yyyy"];
  PASS_EQUAL([formatter stringForObjectValue: date], @"31 décembre 2000",
    "object formatting respects the formatter locale")

  [formatter setLocale:
    [NSLocale localeWithLocaleIdentifier: @"en_US_POSIX"]];
  [formatter setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
  [formatter setDateStyle: NSDateFormatterLongStyle];
  [formatter setTimeStyle: NSDateFormatterNoStyle];
  PASS_EQUAL([formatter stringForObjectValue: date], @"January 1, 2001",
    "object formatting supports date styles without an explicit pattern")
  PASS_EQUAL([formatter stringForObjectValue: date],
    [formatter stringFromDate: date],
    "NSFormatter and NSDateFormatter entry points agree")
#else
  [formatter setDateFormat: @"%Y-%m-%d"];
  PASS_EQUAL([formatter stringForObjectValue: date],
    [date descriptionWithCalendarFormat: @"%Y-%m-%d"
                             timeZone: [NSTimeZone defaultTimeZone]
                               locale: nil],
    "object formatting uses the legacy fallback without ICU")
#endif

  RELEASE(formatter);
  END_SET("NSDateFormatter object formatting")
  return 0;
}
