#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateIntervalFormatter.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSTimeZone.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import "../Shared/TestKeyedArchiver.h"

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
  TestKeyedArchiver *archiver;
  NSMutableData *mdata;
  NSArray *keys;
  NSString *key;
  BOOL allHaveNSPrefix;
  int i;

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

  // Encode using custom archiver to capture keys
  mdata = [NSMutableData data];
  archiver = [[TestKeyedArchiver alloc] initForWritingWithMutableData: mdata];
  [archiver encodeObject: formatter forKey: @"root"];
  [archiver finishEncoding];
  
  keys = [archiver capturedKeys];
  PASS(keys != nil && [keys count] > 0, "Captured encoding keys");

  // Check that all keys use NS prefix (macOS convention)
  allHaveNSPrefix = YES;
  for (i = 0; i < [keys count]; i++)
    {
      key = [keys objectAtIndex: i];
      if (![key isEqualToString: @"root"] && 
          ![key hasPrefix: @"NS"] && 
          ![key hasPrefix: @"$"])
        {
          allHaveNSPrefix = NO;
          NSLog(@"Found non-NS key: %@", key);
          break;
        }
    }
  PASS(allHaveNSPrefix, "All keys use macOS naming convention (NS prefix)");
  
  // Verify specific keys expected by macOS
  PASS([keys containsObject: @"NS.calendar"], 
       "Has NS.calendar key (macOS convention)");
  PASS([keys containsObject: @"NS.locale"], 
       "Has NS.locale key (macOS convention)");
  PASS([keys containsObject: @"NS.timeZone"], 
       "Has NS.timeZone key (macOS convention)");
  PASS([keys containsObject: @"NS.dateTemplate"], 
       "Has NS.dateTemplate key (macOS convention)");
  PASS([keys containsObject: @"NS.dateStyle"], 
       "Has NS.dateStyle key (macOS convention)");
  PASS([keys containsObject: @"NS.timeStyle"], 
       "Has NS.timeStyle key (macOS convention)");
  
  [archiver release];

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
