#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLengthFormatter.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSLengthFormatter macOS encoding compatibility");

  NSLengthFormatter *formatter;
  NSLengthFormatter *decoded;
  NSData *data;
  NSNumberFormatter *nf;
  NSString *original;
  NSString *afterDecode;

  formatter = AUTORELEASE([[NSLengthFormatter alloc] init]);
  
  // Configure with properties
  [formatter setForPersonHeightUse: YES];
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 1];
  [formatter setNumberFormatter: nf];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSLengthFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSLengthFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded isForPersonHeightUse] == [formatter isForPersonHeightUse],
       "forPersonHeightUse survives round-trip");
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  original = [formatter stringFromMeters: 1.75];
  afterDecode = [decoded stringFromMeters: 1.75];
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSLengthFormatter macOS encoding compatibility");
  return 0;
}
