#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSEnergyFormatter.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSLocale.h>

int main()
{
  START_SET("NSEnergyFormatter advanced");

  NSEnergyFormatter *formatter;
  NSString *result;
  NSString *result2;
  NSEnergyFormatterUnit usedUnit;
  BOOL success;

  formatter = AUTORELEASE([[NSEnergyFormatter alloc] init]);

  // Test very large energy values
  result = [formatter stringFromValue: 1000000.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Format 1 million joules");

  result = [formatter stringFromValue: 1000000.0 unit: NSEnergyFormatterUnitCalorie];
  PASS(result != nil && [result length] > 0, "Format 1 million calories");

  // Test very small values
  result = [formatter stringFromValue: 0.001 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Format very small joule value");

  result = [formatter stringFromValue: 0.001 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil && [result length] > 0, "Format very small kilocalorie value");

  // Test negative values
  result = [formatter stringFromValue: -1000.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil, "Handle negative energy value");

  result = [formatter stringFromJoules: -4184.0];
  PASS(result != nil, "Handle negative joules");

  // Test zero
  result = [formatter stringFromValue: 0.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Format zero energy");

  result = [formatter stringFromJoules: 0.0];
  PASS(result != nil && [result length] > 0, "Format zero joules");

  // Test conversion accuracy (1 calorie ≈ 4.184 joules)
  [formatter setForFoodEnergyUse: NO];
  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitCalorie];
  result2 = [formatter stringFromJoules: 4.184];
  PASS(result != nil && result2 != nil, "Calorie to joule conversion");

  // Test food energy vs regular energy
  [formatter setForFoodEnergyUse: YES];
  result = [formatter stringFromJoules: 4184.0]; // ~1 kcal
  [formatter setForFoodEnergyUse: NO];
  result2 = [formatter stringFromJoules: 4184.0];
  PASS(result != nil && result2 != nil, 
       "Food energy vs regular energy produce different formats");

  // Test kilocalorie formatting (food Calories)
  [formatter setForFoodEnergyUse: YES];
  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil && [result length] > 0, "Format food Calorie (kcal)");

  result = [formatter stringFromValue: 2000.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil, "Format typical daily calorie intake");

  // Test kilojoule formatting
  result = [formatter stringFromValue: 1.0 unit: NSEnergyFormatterUnitKilojoule];
  PASS(result != nil && [result length] > 0, "Format 1 kilojoule");

  result = [formatter stringFromValue: 8368.0 unit: NSEnergyFormatterUnitKilojoule];
  PASS(result != nil, "Format ~2000 kcal equivalent in kJ");

  // Test unit styles with different energy values
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil && [result length] > 0, "Short style with joules");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil && [result length] > 0, "Medium style with joules");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromJoules: 1000.0];
  PASS(result != nil && [result length] > 0, "Long style with joules");

  // Test unit string extraction
  result = [formatter unitStringFromValue: 1.0 unit: NSEnergyFormatterUnitJoule];
  PASS(result != nil && [result length] > 0, "Extract joule unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSEnergyFormatterUnitCalorie];
  PASS(result != nil && [result length] > 0, "Extract calorie unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil && [result length] > 0, "Extract kilocalorie unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSEnergyFormatterUnitKilojoule];
  PASS(result != nil && [result length] > 0, "Extract kilojoule unit string");

  // Test unitStringFromJoules with used unit output
  usedUnit = NSEnergyFormatterUnitJoule;
  result = [formatter unitStringFromJoules: 1000.0 usedUnit: &usedUnit];
  PASS(result != nil && [result length] > 0, "Extract unit string from joules");

  result = [formatter unitStringFromJoules: 10000.0 usedUnit: &usedUnit];
  PASS(result != nil, "Extract unit string from larger joule value");

  // Test with nil unit pointer
  result = [formatter unitStringFromJoules: 1000.0 usedUnit: NULL];
  PASS(result != nil && [result length] > 0, 
       "unitStringFromJoules works with NULL unit pointer");

  // Test number formatter customization
  NSNumberFormatter *numFormatter = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [numFormatter setMaximumFractionDigits: 3];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromJoules: 1234.5678];
  PASS(result != nil, "Custom number formatter applied");

  // Reset to default
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter auto-creates when set to nil");

  // Test with various NSNumber types
  result = [formatter stringForObjectValue: @(1000)];
  PASS(result != nil && [result length] > 0, "Format integer NSNumber");

  result = [formatter stringForObjectValue: @(1234.5)];
  PASS(result != nil && [result length] > 0, "Format floating-point NSNumber");

  result = [formatter stringForObjectValue: [NSNumber numberWithDouble: 4184.0]];
  PASS(result != nil && [result length] > 0, "Format double NSNumber");

  // Test with nil and invalid objects
  result = [formatter stringForObjectValue: nil];
  PASS(result != nil, "Handle nil object gracefully");

  result = [formatter stringForObjectValue: @"not a number"];
  PASS(result != nil, "Handle non-number string");

  result = [formatter stringForObjectValue: [NSDate date]];
  PASS(result != nil, "Handle invalid object type");

  // Test food energy with various calorie amounts
  [formatter setForFoodEnergyUse: YES];
  result = [formatter stringFromValue: 100.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil, "Format 100 Calories (kcal)");

  result = [formatter stringFromValue: 500.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil, "Format 500 Calories (kcal)");

  result = [formatter stringFromValue: 2500.0 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil, "Format 2500 Calories (kcal)");

  // Test fractional calories
  result = [formatter stringFromValue: 0.5 unit: NSEnergyFormatterUnitKilocalorie];
  PASS(result != nil, "Format fractional kilocalories");

  // Test boundary between units
  [formatter setForFoodEnergyUse: NO];
  result = [formatter stringFromJoules: 999.9];
  result2 = [formatter stringFromJoules: 1000.0];
  PASS(result != nil && result2 != nil, 
       "Format values at unit boundary");

  // Test consistency across multiple calls
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  [formatter setForFoodEnergyUse: NO];
  result = [formatter stringFromJoules: 5000.0];
  result2 = [formatter stringFromJoules: 5000.0];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  // Test locale sensitivity
  NSLocale *locale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [numFormatter setLocale: locale];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromJoules: 1234.5];
  PASS(result != nil, "US locale formatting works");

  locale = [NSLocale localeWithLocaleIdentifier: @"de_DE"];
  [numFormatter setLocale: locale];
  result = [formatter stringFromJoules: 1234.5];
  PASS(result != nil, "German locale formatting works");

  END_SET("NSEnergyFormatter advanced");
  return 0;
}
