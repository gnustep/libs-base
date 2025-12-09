#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSLocale.h>

int main()
{
  START_SET("NSByteCountFormatter advanced");

  NSByteCountFormatter *formatter;
  NSString *result;
  NSString *result2;

  formatter = AUTORELEASE([[NSByteCountFormatter alloc] init]);

  // Test very large byte counts
  result = [formatter stringFromByteCount: 1099511627776LL]; // 1 TB
  PASS(result != nil && [result length] > 0, "Format 1 TB");

  result = [formatter stringFromByteCount: 1125899906842624LL]; // 1 PB
  PASS(result != nil && [result length] > 0, "Format 1 PB");

  // Test negative byte counts
  result = [formatter stringFromByteCount: -1024];
  PASS(result != nil, "Handle negative byte count");

  // Test zero
  result = [formatter stringFromByteCount: 0];
  PASS(result != nil && [result length] > 0, "Handle zero bytes");

  // Test boundary values
  result = [formatter stringFromByteCount: 1023]; // Just under 1 KB
  PASS(result != nil && [result rangeOfString: @"1023"].location != NSNotFound ||
       [result rangeOfString: @"1,023"].location != NSNotFound, 
       "Format bytes just under 1 KB");

  result = [formatter stringFromByteCount: 1024]; // Exactly 1 KB
  PASS(result != nil, "Format exactly 1 KB");

  result = [formatter stringFromByteCount: 1025]; // Just over 1 KB
  PASS(result != nil, "Format bytes just over 1 KB");

  // Test decimal vs binary differences
  [formatter setCountStyle: NSByteCountFormatterCountStyleDecimal];
  result = [formatter stringFromByteCount: 1000];
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  result2 = [formatter stringFromByteCount: 1024];
  PASS(result != nil && result2 != nil, 
       "Decimal (1000) vs Binary (1024) produce different results");

  // Test file vs memory style differences
  [formatter setCountStyle: NSByteCountFormatterCountStyleFile];
  result = [formatter stringFromByteCount: 1536000];
  [formatter setCountStyle: NSByteCountFormatterCountStyleMemory];
  result2 = [formatter stringFromByteCount: 1536000];
  PASS(result != nil && result2 != nil, "File vs Memory styles work");

  // Test adaptive with various sizes
  [formatter setAdaptive: YES];
  [formatter setAllowedUnits: NSByteCountFormatterUseAll];
  
  result = [formatter stringFromByteCount: 500];
  PASS(result != nil && ([result rangeOfString: @"B"].location != NSNotFound ||
                         [result rangeOfString: @"byte"].location != NSNotFound),
       "Adaptive chooses bytes for small values");

  result = [formatter stringFromByteCount: 5120];
  PASS(result != nil, "Adaptive chooses KB for medium values");

  result = [formatter stringFromByteCount: 5242880];
  PASS(result != nil, "Adaptive chooses MB for larger values");

  // Test unit restrictions with values that would normally use different units
  [formatter setAdaptive: NO];
  [formatter setAllowedUnits: NSByteCountFormatterUseBytes];
  result = [formatter stringFromByteCount: 1048576]; // 1 MB in bytes
  PASS(result != nil, "Force display in bytes");

  [formatter setAllowedUnits: NSByteCountFormatterUseKB];
  result = [formatter stringFromByteCount: 1048576]; // 1 MB in KB
  PASS(result != nil, "Force display in KB");

  [formatter setAllowedUnits: NSByteCountFormatterUseMB];
  result = [formatter stringFromByteCount: 512]; // Small value in MB
  PASS(result != nil, "Force small value to MB");

  // Test fractional values
  [formatter setAllowedUnits: NSByteCountFormatterUseMB];
  result = [formatter stringFromByteCount: 524288]; // 0.5 MB
  PASS(result != nil, "Format fractional MB");

  result = [formatter stringFromByteCount: 786432]; // 0.75 MB
  PASS(result != nil, "Format 0.75 MB");

  // Test includes count and unit combinations
  [formatter setAllowedUnits: NSByteCountFormatterUseKB];
  [formatter setIncludesCount: YES];
  [formatter setIncludesUnit: YES];
  result = [formatter stringFromByteCount: 2048];
  PASS(result != nil && [result length] > 0, 
       "Both count and unit included");

  [formatter setIncludesCount: YES];
  [formatter setIncludesUnit: NO];
  result = [formatter stringFromByteCount: 2048];
  PASS(result != nil && [result length] > 0, 
       "Count included, unit excluded");

  [formatter setIncludesCount: NO];
  [formatter setIncludesUnit: YES];
  result = [formatter stringFromByteCount: 2048];
  PASS(result != nil && [result length] > 0, 
       "Count excluded, unit included");

  // Test zero padding with fractional digits
  [formatter setIncludesCount: YES];
  [formatter setIncludesUnit: YES];
  [formatter setZeroPadsFractionDigits: YES];
  [formatter setAllowedUnits: NSByteCountFormatterUseMB];
  result = [formatter stringFromByteCount: 1048576]; // Exactly 1 MB
  PASS(result != nil, "Zero padding with exact value");

  result = [formatter stringFromByteCount: 1572864]; // 1.5 MB
  PASS(result != nil, "Zero padding with fractional value");

  // Test with nil and invalid objects
  result = [formatter stringForObjectValue: nil];
  PASS(result != nil, "Handle nil object gracefully");

  result = [formatter stringForObjectValue: @"not a number"];
  PASS(result != nil, "Handle non-number object");

  // Test with various NSNumber types
  result = [formatter stringForObjectValue: [NSNumber numberWithLongLong: 1024]];
  PASS(result != nil, "Handle NSNumber integer");

  result = [formatter stringForObjectValue: [NSNumber numberWithDouble: 1024.5]];
  PASS(result != nil, "Handle NSNumber float");

  result = [formatter stringForObjectValue: [NSNumber numberWithLongLong: 1099511627776LL]];
  PASS(result != nil, "Handle NSNumber long long");

  // Test actual byte count inclusion
  [formatter setIncludesActualByteCount: YES];
  [formatter setAllowedUnits: NSByteCountFormatterUseMB];
  result = [formatter stringFromByteCount: 1048576];
  PASS(result != nil, "Includes actual byte count");

  [formatter setIncludesActualByteCount: NO];
  result = [formatter stringFromByteCount: 1048576];
  PASS(result != nil, "Excludes actual byte count");

  // Test nonnumeric formatting
  [formatter setAllowsNonnumericFormatting: YES];
  result = [formatter stringFromByteCount: 0];
  PASS(result != nil, "Nonnumeric formatting for zero");

  [formatter setAllowsNonnumericFormatting: NO];
  result = [formatter stringFromByteCount: 0];
  PASS(result != nil, "Numeric formatting for zero");

  // Test class method with different styles
  result = [NSByteCountFormatter stringFromByteCount: 1048576
                                           countStyle: NSByteCountFormatterCountStyleFile];
  result2 = [NSByteCountFormatter stringFromByteCount: 1048576
                                            countStyle: NSByteCountFormatterCountStyleMemory];
  PASS(result != nil && result2 != nil, "Class method works with different styles");

  // Test consistency across multiple calls
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  [formatter setAllowedUnits: NSByteCountFormatterUseMB];
  result = [formatter stringFromByteCount: 2097152];
  result2 = [formatter stringFromByteCount: 2097152];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  END_SET("NSByteCountFormatter advanced");
  return 0;
}
