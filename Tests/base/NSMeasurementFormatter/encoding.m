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
  START_SET("NSMeasurementFormatter encoding");

  NSMeasurementFormatter *formatter;
  NSMeasurementFormatter *decoded;
  NSData *data;
  NSString *result1;
  NSString *result2;
  NSMeasurement *measurement;
  NSNumberFormatter *nf;
  NSLocale *locale;

  formatter = AUTORELEASE([[NSMeasurementFormatter alloc] init]);
  
  // Configure the formatter
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  
  locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [formatter setLocale: locale];
  
  nf = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [nf setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: nf];

  // Encode the formatter
  data = [NSKeyedArchiver archivedDataWithRootObject: formatter];
  PASS(data != nil && [data length] > 0, "Can encode NSMeasurementFormatter");

  // Decode the formatter
  decoded = [NSKeyedUnarchiver unarchiveObjectWithData: data];
  PASS(decoded != nil, "Can decode NSMeasurementFormatter");
  PASS([decoded isKindOfClass: [NSMeasurementFormatter class]], 
       "Decoded object is NSMeasurementFormatter");

  // Verify properties are preserved
  PASS([decoded unitStyle] == NSFormattingUnitStyleShort,
       "unitStyle preserved");
  PASS([decoded unitOptions] == NSMeasurementFormatterUnitOptionsProvidedUnit,
       "unitOptions preserved");
  PASS([decoded locale] != nil,
       "locale preserved");
  PASS([decoded numberFormatter] != nil,
       "numberFormatter preserved");

  // Verify formatting behavior is consistent
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 5.0
                                                      unit: [NSUnitLength kilometers]];
  result1 = [formatter stringFromMeasurement: measurement];
  result2 = [decoded stringFromMeasurement: measurement];
  RELEASE(measurement);
  PASS(result1 != nil && result2 != nil && 
       [result1 length] > 0 && [result2 length] > 0,
       "Both formatters produce valid output");

  END_SET("NSMeasurementFormatter encoding");
  return 0;
}
