#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSEnergyFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSEnergyFormatter macOS encoding compatibility");

  NSEnergyFormatter *formatter;
  NSEnergyFormatter *decoded;
  NSData *data;
  NSNumberFormatter *nf;
  NSString *original;
  NSString *afterDecode;

  formatter = AUTORELEASE([[NSEnergyFormatter alloc] init]);
  
  // Configure with properties
  [formatter setForFoodEnergyUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 0];
  [formatter setNumberFormatter: nf];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSEnergyFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSEnergyFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded isForFoodEnergyUse] == [formatter isForFoodEnergyUse],
       "forFoodEnergyUse survives round-trip");
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  original = [formatter stringFromJoules: 4184.0];
  afterDecode = [decoded stringFromJoules: 4184.0];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSEnergyFormatter macOS encoding compatibility");
  return 0;
}
