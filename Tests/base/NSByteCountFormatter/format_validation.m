#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSByteCountFormatter.h>

int main()
{
  START_SET("NSByteCountFormatter format validation");

  NSByteCountFormatter *formatter;
  NSString *result;

  formatter = AUTORELEASE([[NSByteCountFormatter alloc] init]);
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  [formatter setAllowsNonnumericFormatting: YES];

  // Test zero bytes
  result = [formatter stringFromByteCount: 0];
  PASS([result rangeOfString: @"Zero"].location != NSNotFound ||
       [result rangeOfString: @"0"].location != NSNotFound,
       "Zero bytes shows 'Zero' or '0'");

  // Test bytes (< 1024)
  result = [formatter stringFromByteCount: 500];
  PASS([result rangeOfString: @"500"].location != NSNotFound &&
       ([result rangeOfString: @"byte"].location != NSNotFound ||
        [result rangeOfString: @"B"].location != NSNotFound),
       "500 bytes format includes number and 'bytes' or 'B'");

  // Test KB (1024)
  result = [formatter stringFromByteCount: 1024];
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       [result rangeOfString: @"KB"].location != NSNotFound,
       "1024 bytes shows as '1 KB'");

  // Test MB
  result = [formatter stringFromByteCount: 1048576]; // 1 MB
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       [result rangeOfString: @"MB"].location != NSNotFound,
       "1 MB format correct");

  // Test GB
  result = [formatter stringFromByteCount: 1073741824]; // 1 GB
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       [result rangeOfString: @"GB"].location != NSNotFound,
       "1 GB format correct");

  // Test fractional values round up
  result = [formatter stringFromByteCount: 1536]; // 1.5 KB
  PASS([result rangeOfString: @"2"].location != NSNotFound &&
       [result rangeOfString: @"KB"].location != NSNotFound,
       "1.5 KB rounds to 2 KB");

  // Test decimal style
  [formatter setCountStyle: NSByteCountFormatterCountStyleDecimal];
  result = [formatter stringFromByteCount: 1000];
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       ([result rangeOfString: @"KB"].location != NSNotFound ||
        [result rangeOfString: @"kB"].location != NSNotFound),
       "1000 bytes in decimal shows as ~1 KB");

  // Test that binary 1024 != decimal 1000
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  NSString *binary1024 = [formatter stringFromByteCount: 1024];
  [formatter setCountStyle: NSByteCountFormatterCountStyleDecimal];
  NSString *decimal1000 = [formatter stringFromByteCount: 1000];
  PASS(![binary1024 isEqualToString: decimal1000],
       "Binary 1024 and decimal 1000 produce different formats");

  END_SET("NSByteCountFormatter format validation");
  return 0;
}
