#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSMeasurement.h>
#import <Foundation/NSUnit.h>

int main()
{
  START_SET("NSMeasurementFormatter basic");

  NSMeasurementFormatter *formatter;
  NSString *result;
  NSMeasurement *measurement;
  NSUnit *unit;

  // Test instance creation
  formatter = AUTORELEASE([[NSMeasurementFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSMeasurementFormatter instance");

  // Test length measurements
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 1.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format 1 meter");

  unit = [NSUnitLength kilometers];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 5.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format 5 kilometers");

  // Test mass measurements
  unit = [NSUnitMass kilograms];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2.5
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format 2.5 kilograms");

  // Test unit styles
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Short unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Medium unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Long unit style works");

  // Test unit options
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 1000.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Provided unit option works");

  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsNaturalScale];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Natural scale option works");

  // Test number formatter
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter is never nil (creates default)");

  // Test stringForObjectValue:
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 10.0
                                                                   unit: unit]);
  result = [formatter stringForObjectValue: measurement];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSMeasurement");

  // Test temperature measurements
  unit = [NSUnitTemperature celsius];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 25.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format temperature in Celsius");

  // Test speed measurements
  unit = [NSUnitSpeed metersPerSecond];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 10.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format speed in m/s");

  // Test volume measurements
  unit = [NSUnitVolume liters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format volume in liters");

  // Test duration measurements
  unit = [NSUnitDuration seconds];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 60.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format duration in seconds");

  // Test area measurements
  unit = [NSUnitArea squareMeters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && [result length] > 0, "Format area in square meters");

  END_SET("NSMeasurementFormatter basic");
  return 0;
}
