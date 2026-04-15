#import <Foundation/Foundation.h>
#import "Testing.h"

static const double epsilon = 1e-6;

static BOOL
doubleEqual(double a, double b)
{
  return fabs(a - b) < epsilon;
}

int
main(int argc, char *argv[])
{
  START_SET("NSMeasurement conversions")

  NSUnitLength *meters = [NSUnitLength meters];
  NSUnitLength *kilometers = [NSUnitLength kilometers];
  NSUnitLength *centimeters = [NSUnitLength centimeters];
  NSUnitLength *miles = [NSUnitLength miles];
  NSUnitLength *feet = [NSUnitLength feet];
  NSUnitLength *inches = [NSUnitLength inches];
  NSUnitLength *yards = [NSUnitLength yards];

  /* --- Basic unit identity conversions --- */

  NSMeasurement *oneMeter = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                  unit:meters];

  PASS(doubleEqual([[oneMeter measurementByConvertingToUnit:meters] doubleValue], 1.0),
       "1 meter converts to 1 meter");

  /* --- Length conversions --- */

  PASS(doubleEqual([[oneMeter measurementByConvertingToUnit:centimeters] doubleValue], 100.0),
       "1 meter = 100 centimeters");

  PASS(doubleEqual([[oneMeter measurementByConvertingToUnit:kilometers] doubleValue], 0.001),
       "1 meter = 0.001 kilometers");

  NSMeasurement *oneKilometer = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                      unit:kilometers];

  PASS(doubleEqual([[oneKilometer measurementByConvertingToUnit:meters] doubleValue], 1000.0),
       "1 kilometer = 1000 meters");

  NSMeasurement *oneMile = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                 unit:miles];

  PASS(doubleEqual([[oneMile measurementByConvertingToUnit:meters] doubleValue], 1609.344),
       "1 mile = 1609.344 meters");

  NSMeasurement *oneFoot = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                  unit:feet];

  PASS(doubleEqual([[oneFoot measurementByConvertingToUnit:inches] doubleValue], 12.0),
       "1 foot = 12 inches");

  NSMeasurement *oneYard = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                  unit:yards];

  PASS(doubleEqual([[oneYard measurementByConvertingToUnit:feet] doubleValue], 3.0),
       "1 yard = 3 feet");

  /* --- Mass conversions --- */

  NSUnitMass *kilograms = [NSUnitMass kilograms];
  NSUnitMass *grams = [NSUnitMass grams];
  NSUnitMass *pounds = [NSUnitMass pounds];
  NSUnitMass *ounces = [NSUnitMass ounces];

  NSMeasurement *oneKilogram = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                     unit:kilograms];

  PASS(doubleEqual([[oneKilogram measurementByConvertingToUnit:grams] doubleValue], 1000.0),
       "1 kilogram = 1000 grams");

  NSMeasurement *onePound = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                  unit:pounds];

  PASS(doubleEqual([[onePound measurementByConvertingToUnit:ounces] doubleValue], 16.0),
       "1 pound = 16 ounces");

  PASS(doubleEqual([[onePound measurementByConvertingToUnit:grams] doubleValue], 453.59237),
       "1 pound = 453.59237 grams");

  /* --- Temperature conversions --- */

  NSUnitTemperature *celsius = [NSUnitTemperature celsius];
  NSUnitTemperature *fahrenheit = [NSUnitTemperature fahrenheit];
  NSUnitTemperature *kelvin = [NSUnitTemperature kelvin];

  NSMeasurement *boilingC = [[NSMeasurement alloc] initWithDoubleValue:100.0
                                                                  unit:celsius];

  PASS(doubleEqual([[boilingC measurementByConvertingToUnit:fahrenheit] doubleValue], 212.0),
       "100 C = 212 F");

  NSMeasurement *freezingC = [[NSMeasurement alloc] initWithDoubleValue:0.0
                                                                   unit:celsius];

  PASS(doubleEqual([[freezingC measurementByConvertingToUnit:fahrenheit] doubleValue], 32.0),
       "0 C = 32 F");

  PASS(doubleEqual([[freezingC measurementByConvertingToUnit:kelvin] doubleValue], 273.15),
       "0 C = 273.15 K");

  NSMeasurement *absoluteZeroK = [[NSMeasurement alloc] initWithDoubleValue:0.0
                                                                        unit:kelvin];

  PASS(doubleEqual([[absoluteZeroK measurementByConvertingToUnit:celsius] doubleValue], -273.15),
       "0 K = -273.15 C");

  /* --- Duration/time conversions --- */

  NSUnitDuration *seconds = [NSUnitDuration seconds];
  NSUnitDuration *minutes = [NSUnitDuration minutes];
  NSUnitDuration *hours = [NSUnitDuration hours];

  NSMeasurement *oneHour = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                 unit:hours];

  PASS(doubleEqual([[oneHour measurementByConvertingToUnit:minutes] doubleValue], 60.0),
       "1 hour = 60 minutes");

  PASS(doubleEqual([[oneHour measurementByConvertingToUnit:seconds] doubleValue], 3600.0),
       "1 hour = 3600 seconds");

  /* --- Speed conversions --- */

  NSUnitSpeed *metersPerSecond = [NSUnitSpeed metersPerSecond];
  NSUnitSpeed *kilometersPerHour = [NSUnitSpeed kilometersPerHour];
  NSUnitSpeed *milesPerHour = [NSUnitSpeed milesPerHour];

  NSMeasurement *oneMs = [[NSMeasurement alloc] initWithDoubleValue:1.0
                                                               unit:metersPerSecond];

  PASS(doubleEqual([[oneMs measurementByConvertingToUnit:kilometersPerHour] doubleValue], 3.6),
       "1 m/s = 3.6 km/h");

  NSMeasurement *sixtyMph = [[NSMeasurement alloc] initWithDoubleValue:60.0
                                                                  unit:milesPerHour];

  PASS(doubleEqual([[sixtyMph measurementByConvertingToUnit:kilometersPerHour] doubleValue], 96.56064),
       "60 mph = 96.56064 km/h");

  /* --- Incompatible unit conversion raises exception --- */

  PASS_EXCEPTION(
    {
      [oneMeter measurementByConvertingToUnit:kilograms];
    },
    NSInvalidArgumentException,
    "Converting length to mass raises NSInvalidArgumentException");

  END_SET("NSMeasurement conversions")

  return 0;
}
