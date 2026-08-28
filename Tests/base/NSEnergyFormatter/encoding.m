#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSEnergyFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSEnergyFormatter encoding");

  NSEnergyFormatter *formatter;
  NSEnergyFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;
  NSNumberFormatter *nf;

  formatter = AUTORELEASE([[NSEnergyFormatter alloc] init]);
  
  // Configure the formatter
  [formatter setForFoodEnergyUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 0];
  [formatter setNumberFormatter: nf];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSEnergyFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSEnergyFormatter");
  PASS([decoded isKindOfClass: [NSEnergyFormatter class]], 
       "Decoded object is NSEnergyFormatter");

  // Verify properties are preserved
  PASS([decoded isForFoodEnergyUse] == YES,
       "forFoodEnergyUse preserved");
  PASS([decoded unitStyle] == NSFormattingUnitStyleLong,
       "unitStyle preserved");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter preserved");

  // Verify formatting behavior is consistent
  result1 = [formatter stringFromJoules: 4184.0];
  result2 = [decoded stringFromJoules: 4184.0];
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSEnergyFormatter encoding");
  return 0;
}
