#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLengthFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSLengthFormatter encoding");

  NSLengthFormatter *formatter;
  NSLengthFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;
  NSNumberFormatter *nf;

  formatter = AUTORELEASE([[NSLengthFormatter alloc] init]);
  
  // Configure the formatter
  [formatter setForPersonHeightUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 1];
  [formatter setNumberFormatter: nf];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSLengthFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSLengthFormatter");
  PASS([decoded isKindOfClass: [NSLengthFormatter class]], 
       "Decoded object is NSLengthFormatter");

  // Verify properties are preserved
  PASS([decoded isForPersonHeightUse] == YES,
       "forPersonHeightUse preserved");
  PASS([decoded unitStyle] == NSFormattingUnitStyleMedium,
       "unitStyle preserved");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter preserved");

  // Verify formatting behavior is consistent
  result1 = [formatter stringFromMeters: 1.75];
  result2 = [decoded stringFromMeters: 1.75];
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSLengthFormatter encoding");
  return 0;
}
