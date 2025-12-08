#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSEnergyFormatter.h>
#import <Foundation/NSNumber.h>

int main()
{
  START_SET("NSEnergyFormatter basic");

  NSEnergyFormatter *formatter;
  NSString *result;
  NSNumber *number;

  // Test instance creation
  formatter = AUTORELEASE([[NSEnergyFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSEnergyFormatter instance");

  // Test basic energy formatting
  result = [formatter stringFromValue: 0.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Format 0 joules");

  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Format 1 joule");

  result = [formatter stringFromValue: 1000.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Format 1000 joules");

  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitKilojoule];
  PASS(result != nil && [result length] > 0, "Format 1 kilojoule");

  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitCalorie];
  PASS(result != nil && [result length] > 0, "Format 1 calorie");

  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil && [result length] > 0, "Format 1 kilocalorie");

  // Test stringFromJoules:
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil && [result length] > 0, "stringFromJoules: works");

  result = [formatter stringFromJoules: 4184.0];
  PASS(result != nil && [result length] > 0, 
       "stringFromJoules: with calorie equivalent");

  // Test unit styles
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil, "Short unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil, "Medium unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil, "Long unit style works");

  // Test for food energy use
  [formatter setForFoodEnergyUse: YES];
  result = [formatter stringFromJoules: 4184.0];
  PASS(result != nil, "Food energy formatting works");

  [formatter setForFoodEnergyUse: NO];
  result = [formatter stringFromJoules: 4184.0];
  PASS(result != nil, "Non-food energy formatting works");

  // Test number formatter property
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter is never nil (creates default)");

  // Test stringForObjectValue:
  number = @(1000.0);
  result = [formatter stringForObjectValue: number];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSNumber");

  // Test unit conversion
  result = [formatter unitStringFromValue: 1.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "unitStringFromValue:unit: works");

  result = [formatter unitStringFromJoules: 1000.0 
                            usedUnit: NULL];
  PASS(result != nil && [result length] > 0, 
       "unitStringFromJoules:usedUnit: works");

  END_SET("NSEnergyFormatter basic");
  return 0;
}
