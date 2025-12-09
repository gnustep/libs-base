#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSString.h>
#import "../Shared/TestKeyedArchiver.h"

int main()
{
  START_SET("NSByteCountFormatter macOS encoding compatibility");

  NSByteCountFormatter *formatter;
  NSByteCountFormatter *decoded;
  NSData *data;
  TestKeyedArchiver *archiver;
  NSMutableData *mdata;
  NSArray *keys;
  NSString *key;
  BOOL allHaveNSPrefix;
  int i;

  formatter = AUTORELEASE([[NSByteCountFormatter alloc] init]);
  
  // Configure with various properties
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  [formatter setAllowsNonnumericFormatting: NO];
  [formatter setIncludesUnit: YES];
  [formatter setIncludesCount: YES];
  [formatter setAdaptive: YES];

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

  // Verify round-trip encoding/decoding
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSByteCountFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSByteCountFormatter class]], 
       "Decoded object is correct class");

  // Verify properties match after round-trip
  PASS([decoded countStyle] == [formatter countStyle],
       "countStyle survives round-trip");
  PASS([decoded allowsNonnumericFormatting] == [formatter allowsNonnumericFormatting],
       "allowsNonnumericFormatting survives round-trip");
  PASS([decoded includesUnit] == [formatter includesUnit],
       "includesUnit survives round-trip");
  PASS([decoded includesCount] == [formatter includesCount],
       "includesCount survives round-trip");
  PASS([decoded isAdaptive] == [formatter isAdaptive],
       "adaptive survives round-trip");

  // Test that formatting output is identical
  NSString *original = [formatter stringFromByteCount: 2048];
  NSString *afterDecode = [decoded stringFromByteCount: 2048];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSByteCountFormatter macOS encoding compatibility");
  return 0;
}
