#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSMeasurement.h>
#import <Foundation/NSUnit.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSData.h>

int main()
{
  START_SET("NSMeasurementFormatter macOS encoding compatibility");

  NSMeasurementFormatter *formatter;
  NSMeasurementFormatter *decoded;
  NSData *data;
  NSNumberFormatter *nf;
  NSLocale *locale;
  NSMeasurement *measurement;
  NSString *original;
  NSString *afterDecode;

  formatter = AUTORELEASE([[NSMeasurementFormatter alloc] init]);
  
  // Configure with properties
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  
  locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: locale];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: nf];

  // Encode and decode
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSMeasurementFormatter");

  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode with NSKeyedUnarchiver");
  PASS([decoded isKindOfClass: [NSMeasurementFormatter class]], 
       "Decoded object is correct class");

  // Verify properties survive round-trip
  PASS([decoded unitStyle] == [formatter unitStyle],
       "unitStyle survives round-trip");
  PASS([decoded unitOptions] == [formatter unitOptions],
       "unitOptions survives round-trip");
  PASS([decoded locale] != nil,
       "locale survives round-trip");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter survives round-trip");

  // Verify formatting works after decode
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 5.0
                                                      unit: [NSUnitLength kilometers]];
  original = [formatter stringFromMeasurement: measurement];
  afterDecode = [decoded stringFromMeasurement: measurement];
  RELEASE(measurement);
  PASS(original != nil && afterDecode != nil,
       "Both formatters produce output");

  END_SET("NSMeasurementFormatter macOS encoding compatibility");
  return 0;
}
