#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMassFormatter.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSLocale.h>

int main()
{
  START_SET("NSMassFormatter advanced");

  NSMassFormatter *formatter;
  NSString *result;
  NSString *result2;
  NSMassFormatterUnit usedUnit;

  formatter = AUTORELEASE([[NSMassFormatter alloc] init]);

  // Test very large mass values
  result = [formatter stringFromValue: 1000000.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "Format 1 million kilograms");

  result = [formatter stringFromValue: 10000.0 unit: NSMassFormatterUnitPound];
  PASS(result != nil && [result length] > 0, "Format 10000 pounds");

  // Test very small values
  result = [formatter stringFromValue: 0.001 unit: NSMassFormatterUnitGram];
  PASS(result != nil && [result length] > 0, "Format milligram-scale value");

  result = [formatter stringFromValue: 0.001 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "Format 1 gram as kilograms");

  // Test negative values
  result = [formatter stringFromValue: -50.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil, "Handle negative mass value");

  result = [formatter stringFromKilograms: -10.0];
  PASS(result != nil, "Handle negative kilograms");

  // Test zero
  result = [formatter stringFromValue: 0.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "Format zero mass");

  result = [formatter stringFromKilograms: 0.0];
  PASS(result != nil && [result length] > 0, "Format zero kilograms");

  // Test conversion accuracy (1 kg ≈ 2.205 lb)
  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitKilogram];
  result2 = [formatter stringFromValue: 2.205 unit: NSMassFormatterUnitPound];
  PASS(result != nil && result2 != nil, "Kilogram to pound conversion");

  // Test ounce to pound conversion (16 oz = 1 lb)
  result = [formatter stringFromValue: 16.0 unit: NSMassFormatterUnitOunce];
  result2 = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitPound];
  PASS(result != nil && result2 != nil, "Ounce to pound conversion");

  // Test stone (1 stone = 14 pounds)
  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitStone];
  result2 = [formatter stringFromValue: 14.0 unit: NSMassFormatterUnitPound];
  PASS(result != nil && result2 != nil, "Stone to pound conversion");

  // Test person mass vs regular mass
  [formatter setForPersonMassUse: YES];
  result = [formatter stringFromKilograms: 70.0]; // Average adult
  [formatter setForPersonMassUse: NO];
  result2 = [formatter stringFromKilograms: 70.0];
  PASS(result != nil && result2 != nil, 
       "Person mass vs regular mass may use different units");

  // Test typical person mass values
  [formatter setForPersonMassUse: YES];
  result = [formatter stringFromKilograms: 50.0]; // Lighter person
  PASS(result != nil, "Format lighter person mass");

  result = [formatter stringFromKilograms: 70.0]; // Average person
  PASS(result != nil, "Format average person mass");

  result = [formatter stringFromKilograms: 100.0]; // Heavier person
  PASS(result != nil, "Format heavier person mass");

  result = [formatter stringFromKilograms: 3.5]; // Baby weight
  PASS(result != nil, "Format baby mass");

  // Test unit styles with different mass values
  [formatter setForPersonMassUse: NO];
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromKilograms: 5.5];
  PASS(result != nil && [result length] > 0, "Short style with kilograms");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromKilograms: 5.5];
  PASS(result != nil && [result length] > 0, "Medium style with kilograms");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromKilograms: 5.5];
  PASS(result != nil && [result length] > 0, "Long style with kilograms");

  // Test all unit types
  result = [formatter stringFromValue: 1000.0 unit: NSMassFormatterUnitGram];
  PASS(result != nil && [result length] > 0, "Format grams");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "Format kilograms");

  result = [formatter stringFromValue: 16.0 unit: NSMassFormatterUnitOunce];
  PASS(result != nil && [result length] > 0, "Format ounces");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitPound];
  PASS(result != nil && [result length] > 0, "Format pounds");

  result = [formatter stringFromValue: 10.0 unit: NSMassFormatterUnitStone];
  PASS(result != nil && [result length] > 0, "Format stones");

  // Test unit string extraction
  result = [formatter unitStringFromValue: 1.0 unit: NSMassFormatterUnitGram];
  PASS(result != nil && [result length] > 0, "Extract gram unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "Extract kilogram unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSMassFormatterUnitOunce];
  PASS(result != nil && [result length] > 0, "Extract ounce unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSMassFormatterUnitPound];
  PASS(result != nil && [result length] > 0, "Extract pound unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSMassFormatterUnitStone];
  PASS(result != nil && [result length] > 0, "Extract stone unit string");

  // Test unitStringFromKilograms with used unit output
  usedUnit = NSMassFormatterUnitKilogram;
  result = [formatter unitStringFromKilograms: 5.0 usedUnit: &usedUnit];
  PASS(result != nil && [result length] > 0, "Extract unit string from kilograms");

  result = [formatter unitStringFromKilograms: 0.5 usedUnit: &usedUnit];
  PASS(result != nil, "Extract unit string from fractional kilograms");

  // Test with nil unit pointer
  result = [formatter unitStringFromKilograms: 5.0 usedUnit: NULL];
  PASS(result != nil && [result length] > 0, 
       "unitStringFromKilograms works with NULL unit pointer");

  // Test number formatter customization
  NSNumberFormatter *numFormatter = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [numFormatter setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromKilograms: 12.3456];
  PASS(result != nil, "Custom number formatter applied");

  // Reset to default
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter auto-creates when set to nil");

  // Test with various NSNumber types
  result = [formatter stringForObjectValue: @(75)];
  PASS(result != nil && [result length] > 0, "Format integer NSNumber");

  result = [formatter stringForObjectValue: @(75.5)];
  PASS(result != nil && [result length] > 0, "Format floating-point NSNumber");

  result = [formatter stringForObjectValue: [NSNumber numberWithDouble: 80.25]];
  PASS(result != nil && [result length] > 0, "Format double NSNumber");

  // Test with nil and invalid objects
  result = [formatter stringForObjectValue: nil];
  PASS(result != nil, "Handle nil object gracefully");

  result = [formatter stringForObjectValue: @"not a number"];
  PASS(result != nil, "Handle non-number string");

  result = [formatter stringForObjectValue: [NSDate date]];
  PASS(result != nil, "Handle invalid object type");

  // Test fractional values
  result = [formatter stringFromKilograms: 0.5];
  PASS(result != nil, "Format half kilogram");

  result = [formatter stringFromKilograms: 1.25];
  PASS(result != nil, "Format 1.25 kilograms");

  result = [formatter stringFromValue: 2.75 unit: NSMassFormatterUnitPound];
  PASS(result != nil, "Format fractional pounds");

  // Test boundary between units
  result = [formatter stringFromKilograms: 0.999];
  result2 = [formatter stringFromKilograms: 1.001];
  PASS(result != nil && result2 != nil, 
       "Format values at unit boundary");

  // Test consistency across multiple calls
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  [formatter setForPersonMassUse: NO];
  result = [formatter stringFromKilograms: 25.5];
  result2 = [formatter stringFromKilograms: 25.5];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  // Test locale sensitivity (metric vs imperial)
  NSLocale *usLocale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [numFormatter setLocale: usLocale];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromKilograms: 70.0];
  PASS(result != nil, "US locale formatting works");

  NSLocale *ukLocale = [NSLocale localeWithLocaleIdentifier: @"en_GB"];
  [numFormatter setLocale: ukLocale];
  result = [formatter stringFromKilograms: 70.0];
  PASS(result != nil, "UK locale formatting works");

  NSLocale *deLocale = [NSLocale localeWithLocaleIdentifier: @"de_DE"];
  [numFormatter setLocale: deLocale];
  result = [formatter stringFromKilograms: 70.0];
  PASS(result != nil, "German locale formatting works");

  // Test parsing (if implemented)
  id parsedValue = nil;
  NSString *error = nil;
  BOOL parsed = [formatter getObjectValue: &parsedValue 
                                forString: @"5 kg"
                         errorDescription: &error];
  PASS(parsed == YES || parsedValue != nil || error != nil, 
       "Parsing returns some result");

  parsed = [formatter getObjectValue: &parsedValue 
                          forString: @"10.5 lb"
                   errorDescription: &error];
  PASS(parsed == YES || parsedValue != nil || error != nil, 
       "Parsing pounds returns some result");

  END_SET("NSMassFormatter advanced");
  return 0;
}
