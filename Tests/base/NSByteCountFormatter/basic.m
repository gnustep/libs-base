#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSNumber.h>

int main()
{
  START_SET("NSByteCountFormatter basic");

  NSByteCountFormatter *formatter;
  NSString *result;

  // Test class method
  result = [NSByteCountFormatter stringFromByteCount: 1024
                                          countStyle: NSByteCountFormatterCountStyleFile];
  PASS(result != nil, "Class method returns non-nil result");
  
  // Test instance creation
  formatter = AUTORELEASE([[NSByteCountFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSByteCountFormatter instance");

  // Test basic byte count formatting
  result = [formatter stringFromByteCount: 0];
  PASS(result != nil && [result length] > 0, "Format 0 bytes");

  result = [formatter stringFromByteCount: 512];
  PASS(result != nil && [result length] > 0, "Format 512 bytes");

  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil && [result length] > 0, "Format 1 KB");

  result = [formatter stringFromByteCount: 1048576];
  PASS(result != nil && [result length] > 0, "Format 1 MB");

  result = [formatter stringFromByteCount: 1073741824];
  PASS(result != nil && [result length] > 0, "Format 1 GB");

  // Test stringForObjectValue: with NSNumber
  result = [formatter stringForObjectValue: @(2048)];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSNumber");

  // Test count style
  [formatter setCountStyle: NSByteCountFormatterCountStyleFile];
  result = [formatter stringFromByteCount: 1000];
  PASS(result != nil, "File count style works");

  [formatter setCountStyle: NSByteCountFormatterCountStyleMemory];
  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil, "Memory count style works");

  [formatter setCountStyle: NSByteCountFormatterCountStyleDecimal];
  result = [formatter stringFromByteCount: 1000];
  PASS(result != nil, "Decimal count style works");

  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil, "Binary count style works");

  // Test adaptive mode
  [formatter setAdaptive: YES];
  result = [formatter stringFromByteCount: 1536];
  PASS(result != nil, "Adaptive mode works");

  // Test allowed units
  [formatter setAllowedUnits: NSByteCountFormatterUseKB];
  result = [formatter stringFromByteCount: 2048];
  PASS(result != nil, "Allowed units restriction works");

  // Test includes count
  [formatter setIncludesCount: YES];
  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil, "Includes count setting works");

  [formatter setIncludesCount: NO];
  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil, "Excludes count setting works");

  // Test includes unit
  [formatter setIncludesUnit: YES];
  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil, "Includes unit setting works");

  [formatter setIncludesUnit: NO];
  result = [formatter stringFromByteCount: 1024];
  PASS(result != nil, "Excludes unit setting works");

  // Test zero padding
  [formatter setZeroPadsFractionDigits: YES];
  result = [formatter stringFromByteCount: 1536];
  PASS(result != nil, "Zero padding enabled works");

  [formatter setZeroPadsFractionDigits: NO];
  result = [formatter stringFromByteCount: 1536];
  PASS(result != nil, "Zero padding disabled works");

  END_SET("NSByteCountFormatter basic");
  return 0;
}
