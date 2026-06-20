#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSByteCountFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSByteCountFormatter encoding");

  NSByteCountFormatter *formatter;
  NSByteCountFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;

  formatter = AUTORELEASE([[NSByteCountFormatter alloc] init]);
  
  // Configure the formatter with various properties
  [formatter setCountStyle: NSByteCountFormatterCountStyleBinary];
  [formatter setAllowsNonnumericFormatting: NO];
  [formatter setIncludesUnit: YES];
  [formatter setIncludesCount: YES];
  [formatter setIncludesActualByteCount: NO];
  [formatter setAdaptive: YES];
  [formatter setZeroPadsFractionDigits: YES];
  [formatter setAllowedUnits: NSByteCountFormatterUseKB | NSByteCountFormatterUseMB];
  [formatter setFormattingContext: NSFormattingContextStandalone];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSByteCountFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSByteCountFormatter");
  PASS([decoded isKindOfClass: [NSByteCountFormatter class]], 
       "Decoded object is NSByteCountFormatter");

  // Verify properties are preserved
  PASS([decoded countStyle] == NSByteCountFormatterCountStyleBinary,
       "Count style preserved");
  PASS([decoded allowsNonnumericFormatting] == NO,
       "allowsNonnumericFormatting preserved");
  PASS([decoded includesUnit] == YES,
       "includesUnit preserved");
  PASS([decoded includesCount] == YES,
       "includesCount preserved");
  PASS([decoded includesActualByteCount] == NO,
       "includesActualByteCount preserved");
  PASS([decoded isAdaptive] == YES,
       "adaptive preserved");
  PASS([decoded zeroPadsFractionDigits] == YES,
       "zeroPadsFractionDigits preserved");
  PASS([decoded allowedUnits] == (NSByteCountFormatterUseKB | NSByteCountFormatterUseMB),
       "allowedUnits preserved");
  PASS([decoded formattingContext] == NSFormattingContextStandalone,
       "formattingContext preserved");

  // Verify formatting behavior is consistent
  result1 = [formatter stringFromByteCount: 2048];
  result2 = [decoded stringFromByteCount: 2048];
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSByteCountFormatter encoding");
  return 0;
}
