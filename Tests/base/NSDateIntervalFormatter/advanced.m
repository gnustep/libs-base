#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateIntervalFormatter.h>
#import <Foundation/NSDateInterval.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSValue.h>

int main()
{
  START_SET("NSDateIntervalFormatter advanced");

  NSDateIntervalFormatter *formatter;
  NSString *result;
  NSString *result2;
  NSDate *startDate;
  NSDate *endDate;
  NSDateInterval *interval;

  formatter = AUTORELEASE([[NSDateIntervalFormatter alloc] init]);
  startDate = [NSDate date];

  // Test very short intervals (seconds)
  endDate = [startDate dateByAddingTimeInterval: 1]; // 1 second
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 1 second interval");

  endDate = [startDate dateByAddingTimeInterval: 30]; // 30 seconds
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 30 second interval");

  // Test minute intervals
  endDate = [startDate dateByAddingTimeInterval: 300]; // 5 minutes
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 5 minute interval");

  endDate = [startDate dateByAddingTimeInterval: 1800]; // 30 minutes
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 30 minute interval");

  // Test hour intervals
  endDate = [startDate dateByAddingTimeInterval: 3600]; // 1 hour
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 1 hour interval");

  endDate = [startDate dateByAddingTimeInterval: 7200]; // 2 hours
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 2 hour interval");

  endDate = [startDate dateByAddingTimeInterval: 43200]; // 12 hours
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 12 hour interval");

  // Test day intervals
  endDate = [startDate dateByAddingTimeInterval: 86400]; // 1 day
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 1 day interval");

  endDate = [startDate dateByAddingTimeInterval: 259200]; // 3 days
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 3 day interval");

  // Test week intervals
  endDate = [startDate dateByAddingTimeInterval: 604800]; // 1 week
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 1 week interval");

  endDate = [startDate dateByAddingTimeInterval: 1209600]; // 2 weeks
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format 2 week interval");

  // Test month intervals (approximate)
  endDate = [startDate dateByAddingTimeInterval: 2592000]; // ~30 days
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format ~1 month interval");

  endDate = [startDate dateByAddingTimeInterval: 7776000]; // ~90 days
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format ~3 month interval");

  // Test year intervals (approximate)
  endDate = [startDate dateByAddingTimeInterval: 31536000]; // ~365 days
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, "Format ~1 year interval");

  // Test with reversed dates (end before start)
  endDate = [startDate dateByAddingTimeInterval: -3600]; // 1 hour earlier
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Handle reversed date order");

  // Test with same dates
  result = [formatter stringFromDate: startDate toDate: startDate];
  PASS(result != nil, "Handle identical dates");

  // Test all date style combinations
  endDate = [startDate dateByAddingTimeInterval: 7200];
  
  [formatter setDateStyle: NSDateIntervalFormatterNoStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "No date style, short time style");

  [formatter setDateStyle: NSDateIntervalFormatterShortStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterNoStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Short date style, no time style");

  [formatter setDateStyle: NSDateIntervalFormatterShortStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Short date and time styles");

  [formatter setDateStyle: NSDateIntervalFormatterMediumStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterMediumStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Medium date and time styles");

  [formatter setDateStyle: NSDateIntervalFormatterLongStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterLongStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Long date and time styles");

  [formatter setDateStyle: NSDateIntervalFormatterFullStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterFullStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Full date and time styles");

  // Test mixed style combinations
  [formatter setDateStyle: NSDateIntervalFormatterShortStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterLongStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Short date, long time");

  [formatter setDateStyle: NSDateIntervalFormatterLongStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Long date, short time");

  // Test various date templates
  [formatter setDateTemplate: @"MMMd"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Month and day template");

  [formatter setDateTemplate: @"yMMMd"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Year, month, and day template");

  [formatter setDateTemplate: @"yMMMdHm"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Year, month, day, hour, minute template");

  [formatter setDateTemplate: @"Hm"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Hour and minute only template");

  [formatter setDateTemplate: @"Hms"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Hour, minute, second template");

  [formatter setDateTemplate: @"yMMMMd"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Full month name template");

  [formatter setDateTemplate: @"EEEE"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Full day name template");

  // Test with NSDateInterval object
  [formatter setDateTemplate: nil];
  [formatter setDateStyle: NSDateIntervalFormatterMediumStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterMediumStyle];
  
  interval = AUTORELEASE([[NSDateInterval alloc] initWithStartDate: startDate
                                                           endDate: [startDate dateByAddingTimeInterval: 3600]]);
  result = [formatter stringFromDateInterval: interval];
  PASS(result != nil && [result length] > 0, "Format NSDateInterval object");

  interval = AUTORELEASE([[NSDateInterval alloc] initWithStartDate: startDate
                                                           endDate: [startDate dateByAddingTimeInterval: 86400]]);
  result = [formatter stringFromDateInterval: interval];
  PASS(result != nil && [result length] > 0, "Format day-long NSDateInterval");

  // Test locale changes
  NSLocale *usLocale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: usLocale];
  endDate = [startDate dateByAddingTimeInterval: 7200];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "US locale formatting");

  NSLocale *ukLocale = [NSLocale localeWithLocaleIdentifier: @"en_GB"];
  [formatter setLocale: ukLocale];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "UK locale formatting");

  NSLocale *frLocale = [NSLocale localeWithLocaleIdentifier: @"fr_FR"];
  [formatter setLocale: frLocale];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "French locale formatting");

  NSLocale *deLocale = [NSLocale localeWithLocaleIdentifier: @"de_DE"];
  [formatter setLocale: deLocale];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "German locale formatting");

  NSLocale *jaLocale = [NSLocale localeWithLocaleIdentifier: @"ja_JP"];
  [formatter setLocale: jaLocale];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Japanese locale formatting");

  // Test time zone changes
  [formatter setLocale: usLocale];
  NSTimeZone *nyTz = [NSTimeZone timeZoneWithName: @"America/New_York"];
  [formatter setTimeZone: nyTz];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "New York time zone");

  NSTimeZone *laTz = [NSTimeZone timeZoneWithName: @"America/Los_Angeles"];
  [formatter setTimeZone: laTz];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Los Angeles time zone");

  NSTimeZone *londonTz = [NSTimeZone timeZoneWithName: @"Europe/London"];
  [formatter setTimeZone: londonTz];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "London time zone");

  NSTimeZone *tokyoTz = [NSTimeZone timeZoneWithName: @"Asia/Tokyo"];
  [formatter setTimeZone: tokyoTz];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Tokyo time zone");

  NSTimeZone *utcTz = [NSTimeZone timeZoneWithAbbreviation: @"UTC"];
  [formatter setTimeZone: utcTz];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "UTC time zone");

  // Test calendar changes
  NSCalendar *gregorian = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierGregorian];
  [formatter setCalendar: gregorian];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Gregorian calendar");

  NSCalendar *buddhist = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierBuddhist];
  [formatter setCalendar: buddhist];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Buddhist calendar");

  NSCalendar *hebrew = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierHebrew];
  [formatter setCalendar: hebrew];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Hebrew calendar");

  NSCalendar *islamic = [NSCalendar calendarWithIdentifier: NSCalendarIdentifierIslamic];
  [formatter setCalendar: islamic];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Islamic calendar");

  // Test consistency across multiple calls
  [formatter setCalendar: gregorian];
  [formatter setTimeZone: utcTz];
  [formatter setLocale: usLocale];
  [formatter setDateStyle: NSDateIntervalFormatterMediumStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  
  endDate = [startDate dateByAddingTimeInterval: 5400]; // 1h 30m
  result = [formatter stringFromDate: startDate toDate: endDate];
  result2 = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  // Test with dates spanning midnight
  NSCalendar *cal = [NSCalendar currentCalendar];
  NSDateComponents *comps = [cal components: NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
                                   fromDate: startDate];
  [comps setHour: 23];
  [comps setMinute: 30];
  NSDate *beforeMidnight = [cal dateFromComponents: comps];
  NSDate *afterMidnight = [beforeMidnight dateByAddingTimeInterval: 3600]; // 30 min + 1h
  result = [formatter stringFromDate: beforeMidnight toDate: afterMidnight];
  PASS(result != nil, "Format interval spanning midnight");

  // Test with dates spanning month boundary
  [comps setDay: 1];
  [comps setHour: 0];
  [comps setMinute: 0];
  NSDate *startOfMonth = [cal dateFromComponents: comps];
  NSDate *endOfPrevMonth = [startOfMonth dateByAddingTimeInterval: -86400];
  result = [formatter stringFromDate: endOfPrevMonth toDate: startOfMonth];
  PASS(result != nil, "Format interval spanning month boundary");

  // Test with dates spanning year boundary  
  [comps setMonth: 1];
  [comps setDay: 1];
  NSDate *startOfYear = [cal dateFromComponents: comps];
  NSDate *endOfPrevYear = [startOfYear dateByAddingTimeInterval: -86400];
  result = [formatter stringFromDate: endOfPrevYear toDate: startOfYear];
  PASS(result != nil, "Format interval spanning year boundary");

  END_SET("NSDateIntervalFormatter advanced");
  return 0;
}
