#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLengthFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import "../Shared/TestKeyedArchiver.h"

int main()
{
  START_SET("NSLengthFormatter macOS encoding compatibility");

  NSLengthFormatter *formatter;
  NSLengthFormatter *decoded;
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

  formatter = AUTORELEASE([[NSLengthFormatter alloc] init]);
  
  // Configure with properties
  [formatter setForPersonHeightUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 1];
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
  PASS(data != nil && [data length] > 0, "Can encode NSLengthFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSLengthFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded isForPersonHeightUse] == [formatter isForPersonHeightUse],
       "forPersonHeightUse survives round-trip");
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  original = [formatter stringFromMeters: 1.75];
  afterDecode = [decoded stringFromMeters: 1.75];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSLengthFormatter macOS encoding compatibility");
  return 0;
}
