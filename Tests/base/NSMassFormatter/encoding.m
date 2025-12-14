#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMassFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSMassFormatter encoding");

  NSMassFormatter *formatter;
  NSMassFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;
  NSNumberFormatter *nf;

  formatter = AUTORELEASE([[NSMassFormatter alloc] init]);
  
  // Configure the formatter
  [formatter setForPersonMassUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: nf];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSMassFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSMassFormatter");
  PASS([decoded isKindOfClass: [NSMassFormatter class]], 
       "Decoded object is NSMassFormatter");

  // Verify properties are preserved
  PASS([decoded isForPersonMassUse] == YES,
       "forPersonMassUse preserved");
  PASS([decoded unitStyle] == NSFormattingUnitStyleShort,
       "unitStyle preserved");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter preserved");

  // Verify formatting behavior is consistent
  result1 = [formatter stringFromKilograms: 75.5];
  result2 = [decoded stringFromKilograms: 75.5];
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSMassFormatter encoding");
  return 0;
}
