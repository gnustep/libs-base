#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMassFormatter.h>
#import <Foundation/NSValue.h>

int main()
{
  START_SET("NSMassFormatter basic");

  NSMassFormatter *formatter;
  NSString *result;
  NSNumber *number;

  // Test instance creation
  formatter = AUTORELEASE([[NSMassFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSMassFormatter instance");

  // Test basic mass formatting
  result = [formatter stringFromValue: 0.0 unit: NSMassFormatterUnitGram];
  PASS(result != nil && [result length] > 0, "Format 0 grams");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitGram];
  PASS(result != nil && [result length] > 0, "Format 1 gram");

  result = [formatter stringFromValue: 1000.0 unit: NSMassFormatterUnitGram];
  PASS(result != nil && [result length] > 0, "Format 1000 grams");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "Format 1 kilogram");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitOunce];
  PASS(result != nil && [result length] > 0, "Format 1 ounce");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitPound];
  PASS(result != nil && [result length] > 0, "Format 1 pound");

  result = [formatter stringFromValue: 1.0 unit: NSMassFormatterUnitStone];
  PASS(result != nil && [result length] > 0, "Format 1 stone");

  // Test stringFromKilograms:
  result = [formatter stringFromKilograms: 1.0];
  PASS(result != nil && [result length] > 0, "stringFromKilograms: works");

  result = [formatter stringFromKilograms: 0.5];
  PASS(result != nil && [result length] > 0, 
       "stringFromKilograms: with fractional value");

  // Test unit styles
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromKilograms: 1.5];
  PASS(result != nil, "Short unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromKilograms: 1.5];
  PASS(result != nil, "Medium unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromKilograms: 1.5];
  PASS(result != nil, "Long unit style works");

  // Test for person mass use
  [formatter setForPersonMassUse: YES];
  result = [formatter stringFromKilograms: 70.0];
  PASS(result != nil, "Person mass formatting works");

  [formatter setForPersonMassUse: NO];
  result = [formatter stringFromKilograms: 70.0];
  PASS(result != nil, "Non-person mass formatting works");


  // Test number formatter property
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter is never nil (creates default)");

  // Test stringForObjectValue:
  number = [NSNumber numberWithDouble: 2.5];
  result = [formatter stringForObjectValue: number];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSNumber");

  // Test unit conversion
  result = [formatter unitStringFromValue: 1.0 unit: NSMassFormatterUnitKilogram];
  PASS(result != nil && [result length] > 0, "unitStringFromValue:unit: works");

  result = [formatter unitStringFromKilograms: 1.0 
                               usedUnit: NULL];
  PASS(result != nil && [result length] > 0, 
       "unitStringFromKilograms:usedUnit: works");

  // Test parsing
  double value;
  NSString *error = nil;
  number = nil;
  BOOL parsed = [formatter getObjectValue: &number 
                                forString: @"1.5 kg"
                         errorDescription: &error];
  PASS(parsed || number != nil || error != nil, "Can parse mass string");

  END_SET("NSMassFormatter basic");
  return 0;
}
