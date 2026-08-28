#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateIntervalFormatter.h>
#import <Foundation/NSDateInterval.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSValue.h>

int main()
{
  START_SET("NSDateIntervalFormatter basic");

  NSDateIntervalFormatter *formatter;
  NSString *result;
  NSDate *startDate;
  NSDate *endDate;
  NSDateInterval *interval;

  // Test instance creation
  formatter = AUTORELEASE([[NSDateIntervalFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSDateIntervalFormatter instance");

  // Create test dates
  startDate = [NSDate date];
  endDate = [startDate dateByAddingTimeInterval: 3600]; // 1 hour later

  // Test basic date interval formatting
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil && [result length] > 0, 
       "Format date interval (1 hour)");

  // Test with date interval object
  interval = AUTORELEASE([[NSDateInterval alloc] initWithStartDate: startDate
                                                           endDate: endDate]);
  result = [formatter stringFromDateInterval: interval];
  PASS(result != nil && [result length] > 0, 
       "Format NSDateInterval object");

  // Test date styles
  [formatter setDateStyle: NSDateIntervalFormatterNoStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "No date style works");

  [formatter setDateStyle: NSDateIntervalFormatterShortStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Short date style works");

  [formatter setDateStyle: NSDateIntervalFormatterMediumStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Medium date style works");

  [formatter setDateStyle: NSDateIntervalFormatterLongStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Long date style works");

  [formatter setDateStyle: NSDateIntervalFormatterFullStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Full date style works");

  // Test time styles
  [formatter setTimeStyle: NSDateIntervalFormatterNoStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "No time style works");

  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Short time style works");

  [formatter setTimeStyle: NSDateIntervalFormatterMediumStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Medium time style works");

  [formatter setTimeStyle: NSDateIntervalFormatterLongStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Long time style works");

  [formatter setTimeStyle: NSDateIntervalFormatterFullStyle];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Full time style works");

  // Test date template
  [formatter setDateTemplate: @"MMMMd"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Date template works");

  [formatter setDateTemplate: @"yMMMd"];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Year-month-day template works");

  // Test locale
  NSLocale *locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: locale];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "US locale works");

  locale = [NSLocale localeWithLocaleIdentifier: @"fr_FR"];
  [formatter setLocale: locale];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "French locale works");

  // Test time zone
  NSTimeZone *tz = [NSTimeZone timeZoneWithName: @"America/New_York"];
  [formatter setTimeZone: tz];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Time zone setting works");

  // Test calendar
  NSCalendar *calendar = [NSCalendar currentCalendar];
  [formatter setCalendar: calendar];
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Calendar setting works");

  // Test different interval lengths
  endDate = [startDate dateByAddingTimeInterval: 86400]; // 1 day later
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Format 1 day interval");

  endDate = [startDate dateByAddingTimeInterval: 604800]; // 1 week later
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Format 1 week interval");

  endDate = [startDate dateByAddingTimeInterval: 2592000]; // ~1 month later
  result = [formatter stringFromDate: startDate toDate: endDate];
  PASS(result != nil, "Format 1 month interval");

  END_SET("NSDateIntervalFormatter basic");
  return 0;
}
