#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDateComponentsFormatter.h>
#import <Foundation/NSCalendar.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import "../Shared/TestKeyedArchiver.h"

int main()
{
  START_SET("NSDateComponentsFormatter macOS encoding compatibility");

  NSDateComponentsFormatter *formatter;
  NSDateComponentsFormatter *decoded;
  NSData *data;
  NSCalendar *calendar;
  NSString *original;
  NSString *afterDecode;
  TestKeyedArchiver *archiver;
  NSMutableData *mdata;
  NSArray *keys;
  NSString *key;
  BOOL allHaveNSPrefix;
  int i;

  formatter = AUTORELEASE([[NSDateComponentsFormatter alloc] init]);
  
  // Configure with basic properties
  [formatter setUnitsStyle: NSDateComponentsFormatterUnitsStyleAbbreviated];
  [formatter setAllowedUnits: NSCalendarUnitHour | NSCalendarUnitMinute];
  [formatter setMaximumUnitCount: 2];
  
  calendar = [NSCalendar currentCalendar];
  [formatter setCalendar: calendar];

  // Encode using custom archiver to capture keys
  mdata = [NSMutableData data];
  archiver = [[TestKeyedArchiver alloc] initForWritingWithMutableData: mdata];
  [archiver encodeObject: formatter forKey: @"root"];
  [archiver finishEncoding];
  
  keys = [archiver capturedKeys];
  PASS(keys != nil && [keys count] > 0, "Captured encoding keys");

  // Check that all keys use NS. prefix (macOS convention)
  allHaveNSPrefix = YES;
  for (i = 0; i < [keys count]; i++)
    {
      key = [keys objectAtIndex: i];
      if (![key isEqualToString: @"root"] && 
          ![key hasPrefix: @"NS."] && 
          ![key hasPrefix: @"$"])
        {
          allHaveNSPrefix = NO;
          NSLog(@"Found non-NS key: %@", key);
          break;
        }
    }
  PASS(allHaveNSPrefix, "All keys use macOS naming convention (NS. prefix)");
  
  [archiver release];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSDateComponentsFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSDateComponentsFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded unitsStyle] == [formatter unitsStyle],
       "unitsStyle survives round-trip");
  PASS([decoded allowedUnits] == [formatter allowedUnits],
       "allowedUnits survives round-trip");
  PASS([decoded maximumUnitCount] == [formatter maximumUnitCount],
       "maximumUnitCount survives round-trip");
  PASS([decoded calendar] != nil,
       "calendar survives round-trip");

  // Verify formatting works after decode
  original = [formatter stringFromTimeInterval: 3665];
  afterDecode = [decoded stringFromTimeInterval: 3665];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSDateComponentsFormatter macOS encoding compatibility");
  return 0;
}
