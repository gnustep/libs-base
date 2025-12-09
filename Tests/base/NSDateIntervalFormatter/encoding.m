#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateIntervalFormatter.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSDateIntervalFormatter encoding");

  NSDateIntervalFormatter *formatter;
  NSDateIntervalFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;
  NSCalendar *calendar;
  NSLocale *locale;
  NSTimeZone *timeZone;
  NSDate *startDate;
  NSDate *endDate;

  formatter = AUTORELEASE([[NSDateIntervalFormatter alloc] init]);
  
  // Configure the formatter
  [formatter setDateStyle: NSDateIntervalFormatterMediumStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  [formatter setDateTemplate: @"yMMMd"];
  
  calendar = [NSCalendar currentCalendar];
  [formatter setCalendar: calendar];
  
  locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: locale];
  
  timeZone = [NSTimeZone timeZoneWithName: @"America/New_York"];
  [formatter setTimeZone: timeZone];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSDateIntervalFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSDateIntervalFormatter");
  PASS([decoded isKindOfClass: [NSDateIntervalFormatter class]], 
       "Decoded object is NSDateIntervalFormatter");

  // Verify properties are preserved
  PASS([decoded dateStyle] == NSDateIntervalFormatterMediumStyle,
       "dateStyle preserved");
  PASS([decoded timeStyle] == NSDateIntervalFormatterShortStyle,
       "timeStyle preserved");
  PASS([[decoded dateTemplate] isEqualToString: @"yMMMd"],
       "dateTemplate preserved");
  PASS([decoded calendar] != nil,
       "calendar preserved");
  PASS([decoded locale] != nil,
       "locale preserved");
  PASS([decoded timeZone] != nil,
       "timeZone preserved");

  // Verify formatting behavior is consistent
  startDate = [NSDate date];
  endDate = [startDate dateByAddingTimeInterval: 3600];
  result1 = [formatter stringFromDate: startDate toDate: endDate];
  result2 = [decoded stringFromDate: startDate toDate: endDate];
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSDateIntervalFormatter encoding");
  return 0;
}
