#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSEnergyFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import "../Shared/TestKeyedArchiver.h"

int main()
{
  START_SET("NSEnergyFormatter macOS encoding compatibility");

  NSEnergyFormatter *formatter;
  NSEnergyFormatter *decoded;
  NSData *data;
  NSNumberFormatter *nf;
  NSString *original;
  NSString *afterDecode;
  TestKeyedArchiver *archiver;
  NSMutableData *mdata;
  NSArray *keys;
  NSString *key;
  BOOL allHaveNSPrefix;
  int i;

  formatter = AUTORELEASE([[NSEnergyFormatter alloc] init]);
  
  // Configure with properties
  [formatter setForFoodEnergyUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 0];
  [formatter setNumberFormatter: nf];

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
  PASS([keys containsObject: @"NS.numberFormatter"], 
       "Has NS.numberFormatter key (macOS convention)");
  PASS([keys containsObject: @"NS.unitOptions"], 
       "Has NS.unitOptions key (macOS convention)");
  
  [archiver release];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSEnergyFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSEnergyFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded isForFoodEnergyUse] == [formatter isForFoodEnergyUse],
       "forFoodEnergyUse survives round-trip");
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  original = [formatter stringFromJoules: 4184.0];
  afterDecode = [decoded stringFromJoules: 4184.0];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSEnergyFormatter macOS encoding compatibility");
  return 0;
}
