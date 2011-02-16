#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSLocale *locale;
  NSString *str;
  NSDate *date;
  id current;
  id localh = [NSTimeZone defaultTimeZone];
  int offset = [localh secondsFromGMT];

  current = [NSTimeZone timeZoneForSecondsFromGMT: 900];
  PASS(current != nil && [current isKindOfClass: [NSTimeZone class]]
       && [current secondsFromGMT] == 900,
       "+timeZoneForSecondsFromGMT works");

  current = [NSTimeZone timeZoneForSecondsFromGMT: -45];
  PASS(current != nil && [current isKindOfClass: [NSTimeZone class]]
       && [current secondsFromGMT] == -60,
       "+timeZoneForSecondsFromGMT rounds to minute");

  current = [NSTimeZone timeZoneForSecondsFromGMT: 7260];
  PASS(current != nil && [current isKindOfClass: [NSTimeZone class]]
       && [[current name] isEqual: @"GMT+0201"],
       "+timeZoneForSecondsFromGMT has correct name");

  current = [NSTimeZone timeZoneForSecondsFromGMT: -3600];
  PASS(current != nil && [current isKindOfClass: [NSTimeZone class]]
       && [[current abbreviation] isEqual: @"GMT-0100"],
       "+timeZoneForSecondsFromGMT has correct abbreviation");

  current = [NSTimeZone timeZoneForSecondsFromGMT: -3600];
  PASS(current != nil && [current isKindOfClass: [NSTimeZone class]]
       && [current isDaylightSavingTime] == NO,
       "+timeZoneForSecondsFromGMT has DST NO");

  current = [NSTimeZone timeZoneForSecondsFromGMT: offset];
  [NSTimeZone setDefaultTimeZone: current];
  current = [NSTimeZone localTimeZone];
  PASS(current != nil && [current isKindOfClass: [NSTimeZone class]]
       && [current secondsFromGMT] == offset
       && [current isDaylightSavingTime] == NO,
       "can set default time zone");
  
  current = [NSTimeZone timeZoneWithName: @"America/Sao_Paulo"];
  locale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_GB"];
  str = [current localizedName: NSTimeZoneNameStyleStandard locale: locale];
  PASS_EQUAL (str, @"Brasilia Time",
    "Correctly localizes standard time zone name");
  str = [current localizedName: NSTimeZoneNameStyleShortStandard
    locale: locale];
  PASS_EQUAL (str, @"GMT-03:00", "Correctly localizes short time zone name");
  str = [current localizedName: NSTimeZoneNameStyleDaylightSaving
    locale: locale];
  PASS_EQUAL (str, @"Brasilia Summer Time",
    "Correctly localizes DST time zone name");
  str = [current localizedName: NSTimeZoneNameStyleShortDaylightSaving
    locale: locale];
  PASS_EQUAL (str, @"GMT-02:00",
    "Correctly localizes short DST time zone name");
  RELEASE(locale);
  
  date = [NSDate dateWithTimeIntervalSince1970: 1.0];
  PASS ([current daylightSavingTimeOffsetForDate: date] == 0.0,
    "Returns correct Daylight Saving offset.");
  date = [NSDate dateWithTimeIntervalSince1970: 1297308214.0];
  PASS ([current daylightSavingTimeOffsetForDate: date] == 3600.0,
    "Returns correct Daylight Saving offset.");
  date = [NSDate date];
  PASS ([current daylightSavingTimeOffset] == [current daylightSavingTimeOffsetForDate: date],
    "Returns correct Daylight Saving offset.");
  
  [arp release]; arp = nil;
  return 0;
}
