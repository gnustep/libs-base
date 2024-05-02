#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

#if	defined(GS_USE_ICU)
#define	NSLOCALE_SUPPORTED	GS_USE_ICU
#else
#define	NSLOCALE_SUPPORTED	1 /* Assume Apple support */
#endif

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSLocale *locale;
  NSString *str;
  NSDate *date;
  NSArray *zones;
  id current;
  id localh = [NSTimeZone defaultTimeZone];
  int offset = [localh secondsFromGMT];

  zones = [NSTimeZone knownTimeZoneNames];
  PASS(zones != nil, "+knownTimeZoneNames returns valid array");

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

  START_SET("NSLocale")
  if (!NSLOCALE_SUPPORTED)
    SKIP("NSLocale not supported\nThe ICU library was not available when GNUstep-base was built")

  current = [NSTimeZone timeZoneWithName: @"Europe/Brussels"];
  date = [current nextDaylightSavingTimeTransitionAfterDate:
    [NSDate dateWithString: @"2013-06-08 20:00:00 +0200"]];
  PASS_EQUAL(date, [NSDate dateWithString: @"2013-10-27 03:00:00 +0200"],
    "can calculate next DST transition");

  locale = [[NSLocale alloc] initWithLocaleIdentifier: @"en_GB"];

  current = [NSTimeZone timeZoneWithName: @"Europe/Brussels"];

  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleStandard locale: locale],
    @"Central European Standard Time",
    "Correctly localizes Europe/Brussels standard time zone name")
  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleDaylightSaving locale: locale],
    @"Central European Summer Time",
    "Correctly localizes Europe/Brussels DST time zone name")
  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleShortStandard locale: locale],
    @"CET",
    "Correctly localizes Europe/Brussels short time zone name")
  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleShortDaylightSaving
      locale: locale],
    @"CEST",
    "Correctly localizes Europe/Brussels short DST time zone name")

  current = [NSTimeZone timeZoneWithName: @"America/Sao_Paulo"];

  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleStandard locale: locale],
    @"Brasilia Standard Time",
    "Correctly localizes America/Sao_Paulo standard time zone name")
  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleDaylightSaving locale: locale],
    @"Brasilia Summer Time",
    "Correctly localizes America/Sao_Paulo DST time zone name")
testHopeful = YES;
  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleShortStandard locale: locale],
    @"GMT-3",
    "Correctly localizes America/Sao_Paulo short time zone name")
  PASS_EQUAL(
    [current localizedName: NSTimeZoneNameStyleShortDaylightSaving
      locale: locale],
    @"GMT-3",
    "Correctly localizes America/Sao_Paulo short DST time zone name")
testHopeful = NO;

  RELEASE(locale);
  
  date = [NSDate dateWithTimeIntervalSince1970: 1.0];
  PASS ([current daylightSavingTimeOffsetForDate: date] == 0.0,
    "Returns correct Daylight Saving offset.")
  date = [NSDate dateWithTimeIntervalSince1970: 1297308214.0];
  PASS ([current daylightSavingTimeOffsetForDate: date] == 3600.0,
    "Returns correct Daylight Saving offset.")
  date = [NSDate date];
  PASS ([current daylightSavingTimeOffset]
    == [current daylightSavingTimeOffsetForDate: date],
    "Returns correct Daylight Saving offset.")
  
  END_SET("NSLocale")

  [arp release]; arp = nil;
  return 0;
}
