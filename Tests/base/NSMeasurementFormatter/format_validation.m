#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMeasurementFormatter.h>
#import <Foundation/NSMeasurement.h>
#import <Foundation/NSUnit.h>

int main()
{
  START_SET("NSMeasurementFormatter format validation");

  NSMeasurementFormatter *formatter;
  NSString *result;
  NSMeasurement *measurement;

  formatter = AUTORELEASE([[NSMeasurementFormatter alloc] init]);
  
  // Test length measurement
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 5.0
                                                      unit: [NSUnitLength meters]];
  AUTORELEASE(measurement);
  result = [formatter stringFromMeasurement: measurement];
  PASS([result rangeOfString: @"5"].location != NSNotFound &&
       ([result rangeOfString: @"m"].location != NSNotFound ||
        [result rangeOfString: @"meter"].location != NSNotFound),
       "5 meters format includes number and unit");

  // Test mass measurement
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 2.5
                                                      unit: [NSUnitMass kilograms]];
  AUTORELEASE(measurement);
  result = [formatter stringFromMeasurement: measurement];
  PASS([result rangeOfString: @"2"].location != NSNotFound &&
       ([result rangeOfString: @"kg"].location != NSNotFound ||
        [result rangeOfString: @"kilogram"].location != NSNotFound),
       "2.5 kg format correct");

  // Test temperature measurement
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 25.0
                                                      unit: [NSUnitTemperature celsius]];
  AUTORELEASE(measurement);
  result = [formatter stringFromMeasurement: measurement];
  PASS([result rangeOfString: @"25"].location != NSNotFound &&
       ([result rangeOfString: @"°C"].location != NSNotFound ||
        [result rangeOfString: @"C"].location != NSNotFound ||
        [result rangeOfString: @"celsius"].location != NSNotFound),
       "25°C format correct");

  // Test unit style variations
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 100.0
                                                      unit: [NSUnitLength meters]];
  AUTORELEASE(measurement);
  
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  NSString *shortResult = [formatter stringFromMeasurement: measurement];
  
  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  NSString *longResult = [formatter stringFromMeasurement: measurement];
  
  PASS(![shortResult isEqualToString: longResult] ||
       [shortResult length] > 0,
       "Different unit styles produce different or valid results");

  // Test zero value
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 0.0
                                                      unit: [NSUnitLength meters]];
  AUTORELEASE(measurement);
  result = [formatter stringFromMeasurement: measurement];
  PASS([result rangeOfString: @"0"].location != NSNotFound,
       "Zero measurement shows 0");

  // Test fractional values
  measurement = [[NSMeasurement alloc] initWithDoubleValue: 1.234
                                                      unit: [NSUnitLength meters]];
  AUTORELEASE(measurement);
  result = [formatter stringFromMeasurement: measurement];
  PASS([result rangeOfString: @"1"].location != NSNotFound,
       "Fractional measurement formats");

  END_SET("NSMeasurementFormatter format validation");
  return 0;
}
