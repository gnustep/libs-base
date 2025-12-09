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
  START_SET("NSDateIntervalFormatter macOS encoding compatibility");

  NSDateIntervalFormatter *formatter;
  NSDateIntervalFormatter *decoded;
  NSData *data;
  NSCalendar *calendar;
  NSLocale *locale;
  NSTimeZone *timeZone;
  NSDate *startDate;
  NSDate *endDate;
  NSString *original;
  NSString *afterDecode;

  formatter = AUTORELEASE([[NSDateIntervalFormatter alloc] init]);
  
  // Configure with properties
  [formatter setDateStyle: NSDateIntervalFormatterMediumStyle];
  [formatter setTimeStyle: NSDateIntervalFormatterShortStyle];
  [formatter setDateTemplate: @"yMMMd"];
  
  calendar = [NSCalendar currentCalendar];
  [formatter setCalendar: calendar];
  
  locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: locale];
  
  timeZone = [NSTimeZone timeZoneWithName: @"America/New_York"];
  [formatter setTimeZone: timeZone];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSDateIntervalFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSDateIntervalFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded dateStyle] == [formatter dateStyle],
       "dateStyle survives round-trip");
  PASS([decoded timeStyle] == [formatter timeStyle],
       "timeStyle survives round-trip");
  PASS([[decoded dateTemplate] isEqualToString: [formatter dateTemplate]],
       "dateTemplate survives round-trip");
  PASS([decoded calendar] != nil,
       "calendar survives round-trip");
  PASS([decoded locale] != nil,
       "locale survives round-trip");
  PASS([decoded timeZone] != nil,
       "timeZone survives round-trip");

  // Verify formatting works after decode
  startDate = [NSDate date];
  endDate = [startDate dateByAddingTimeInterval: 3600];
  original = [formatter stringFromDate: startDate toDate: endDate];
  afterDecode = [decoded stringFromDate: startDate toDate: endDate];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSDateIntervalFormatter macOS encoding compatibility");
  return 0;
}
