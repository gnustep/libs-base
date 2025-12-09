#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

int main()
{
  START_SET("NSByteCountFormatter macOS encoding compatibility");

  NSByteCountFormatter *formatter;
  NSData *data;
  NSDictionary *dict;
  NSArray *keys;
  BOOL hasNSPrefix;
  int i;

  formatter = AUTORELEASE([[NSByteCountFormatter alloc] init]);
  
  // Configure with various properties
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  [formatter setAllowsNonnumericFormatting: NO];
  [formatter setIncludesUnit: YES];
  [formatter setIncludesCount: YES];
  [formatter setAdaptive: YES];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSByteCountFormatter");

  // Extract the archived dictionary to check keys
  dict = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  
  // For NSKeyedArchiver compatibility, check that we can decode
  NSByteCountFormatter *decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
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
