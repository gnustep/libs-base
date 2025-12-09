#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMassFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSMassFormatter macOS encoding compatibility");

  NSMassFormatter *formatter;
  NSMassFormatter *decoded;
  NSData *data;
  NSNumberFormatter *nf;
  NSString *original;
  NSString *afterDecode;

  formatter = AUTORELEASE([[NSMassFormatter alloc] init]);
  
  // Configure with properties
  [formatter setForPersonMassUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: nf];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSMassFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSMassFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded isForPersonMassUse] == [formatter isForPersonMassUse],
       "forPersonMassUse survives round-trip");
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  original = [formatter stringFromKilograms: 75.5];
  afterDecode = [decoded stringFromKilograms: 75.5];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSMassFormatter macOS encoding compatibility");
  return 0;
}
