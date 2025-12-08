#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSMeasurement.h>
#import <Foundation/NSUnit.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSLocale.h>
#import <Foundation/NSValue.h>

int main()
{
  START_SET("NSMeasurementFormatter advanced");

  NSMeasurementFormatter *formatter;
  NSString *result;
  NSString *result2;
  NSMeasurement *measurement;
  NSUnit *unit;

  formatter = AUTORELEASE([[NSMeasurementFormatter alloc] init]);

  // Test length conversions
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 1000.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 1000 meters");

  unit = [NSUnitLength centimeters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2.5
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 2.5 centimeters");

  unit = [NSUnitLength millimeters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 150.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 150 millimeters");

  unit = [NSUnitLength inches];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 12.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 12 inches");

  unit = [NSUnitLength feet];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 6.5
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 6.5 feet");

  unit = [NSUnitLength miles];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 26.2
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 26.2 miles (marathon)");

  // Test mass measurements with various units
  unit = [NSUnitMass grams];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 500.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 500 grams");

  unit = [NSUnitMass milligrams];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 250.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 250 milligrams");

  unit = [NSUnitMass ounces];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 16.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 16 ounces");

  unit = [NSUnitMass pounds];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 150.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 150 pounds");

  // Test temperature with various scales
  unit = [NSUnitTemperature celsius];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 0.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 0°C (freezing point)");

  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 100°C (boiling point)");

  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: -40.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format -40°C (same as -40°F)");

  unit = [NSUnitTemperature fahrenheit];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 32.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 32°F (freezing point)");

  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 212.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 212°F (boiling point)");

  unit = [NSUnitTemperature kelvin];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 273.15
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 273.15 K (freezing point)");

  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 0.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 0 K (absolute zero)");

  // Test speed measurements
  unit = [NSUnitSpeed metersPerSecond];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 100 m/s");

  unit = [NSUnitSpeed kilometersPerHour];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 120.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 120 km/h");

  unit = [NSUnitSpeed milesPerHour];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 65.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 65 mph");

  unit = [NSUnitSpeed knots];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 30.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 30 knots");

  // Test volume measurements
  unit = [NSUnitVolume liters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 5.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 5 liters");

  unit = [NSUnitVolume milliliters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 250.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 250 milliliters");

  unit = [NSUnitVolume gallons];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 10.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 10 gallons");

  unit = [NSUnitVolume cubicMeters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2.5
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 2.5 cubic meters");

  // Test duration measurements
  unit = [NSUnitDuration seconds];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 3600.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 3600 seconds");

  unit = [NSUnitDuration minutes];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 90.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 90 minutes");

  unit = [NSUnitDuration hours];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 24.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 24 hours");

  // Test area measurements
  unit = [NSUnitArea squareMeters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 100 square meters");

  unit = [NSUnitArea squareKilometers];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2.5
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 2.5 square kilometers");

  unit = [NSUnitArea acres];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 40.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 40 acres");

  // Test pressure measurements
  unit = [NSUnitPressure newtonsPerMetersSquared];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 101325.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format atmospheric pressure in Pa");

  unit = [NSUnitPressure bars];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 1.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 1 bar");

  // Test energy measurements
  unit = [NSUnitEnergy joules];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 1000.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 1000 joules");

  unit = [NSUnitEnergy kilocalories];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2000.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 2000 kcal");

  // Test power measurements
  unit = [NSUnitPower watts];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 100 watts");

  unit = [NSUnitPower kilowatts];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 2.5
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format 2.5 kilowatts");

  // Test unit styles with different measurements
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                                   unit: unit]);
  
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Short unit style");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Medium unit style");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Long unit style");

  // Test unit options
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 5000.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Provided unit option (keep meters)");

  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsNaturalScale];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Natural scale option (may convert to km)");

  // Test with very small values
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  unit = [NSUnitLength meters];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 0.001
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format very small measurement");

  // Test with very large values
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 1000000.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format very large measurement");

  // Test with negative values
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: -50.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format negative measurement");

  // Test with zero
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 0.0
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Format zero measurement");

  // Test number formatter customization
  NSNumberFormatter *numFormatter = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [numFormatter setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: numFormatter];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 12.3456
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "Custom number formatter applied");

  // Reset to default
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter auto-creates when set to nil");

  // Test stringForObjectValue
  unit = [NSUnitMass kilograms];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 75.0
                                                                   unit: unit]);
  result = [formatter stringForObjectValue: measurement];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSMeasurement");

  result = [formatter stringForObjectValue: nil];
  PASS(result != nil, "Handle nil object");

  result = [formatter stringForObjectValue: @"not a measurement"];
  PASS(result != nil, "Handle non-measurement object");

  // Test consistency
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  [formatter setUnitOptions: NSMeasurementFormatterUnitOptionsProvidedUnit];
  unit = [NSUnitLength kilometers];
  measurement = AUTORELEASE([[NSMeasurement alloc] initWithDoubleValue: 42.195
                                                                   unit: unit]);
  result = [formatter stringFromMeasurement: measurement];
  result2 = [formatter stringFromMeasurement: measurement];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  // Test locale sensitivity
  NSLocale *usLocale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [numFormatter setLocale: usLocale];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "US locale formatting");

  NSLocale *deLocale = [NSLocale localeWithLocaleIdentifier: @"de_DE"];
  [numFormatter setLocale: deLocale];
  result = [formatter stringFromMeasurement: measurement];
  PASS(result != nil, "German locale formatting");

  END_SET("NSMeasurementFormatter advanced");
  return 0;
}
