#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSMeasurement.h>
#import <Foundation/NSUnit.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import "../Shared/TestKeyedArchiver.h"

int main()
{
  START_SET("NSMeasurementFormatter macOS encoding compatibility");

  NSMeasurementFormatter *formatter;
  NSMeasurementFormatter *decoded;
  NSData *data;
  NSNumberFormatter *nf;
  NSLocale *locale;
  NSMeasurement *measurement;
  NSString *original;
  NSString *afterDecode;
  TestKeyedArchiver *archiver;
  NSMutableData *mdata;
  NSArray *keys;
  NSString *key;
  BOOL allHaveNSPrefix;
  int i;

  formatter = AUTORELEASE([[NSMeasurementFormatter alloc] init]);
  
  // Configure with properties
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  
  locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: locale];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: nf];

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
  PASS(data != nil && [data length] > 0, "Can encode NSMeasurementFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSMeasurementFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded unitOptions] == [formatter unitOptions],
       "unitOptions survives round-trip");
  PASS([decoded locale] != nil,
       "locale survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 5.0
                                                      unit: [NSUnitLength kilometers]];
  original = [formatter stringFromMeasurement: measurement];
  afterDecode = [decoded stringFromMeasurement: measurement];
  RELEASE(measurement);
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSMeasurementFormatter macOS encoding compatibility");
  return 0;
}
