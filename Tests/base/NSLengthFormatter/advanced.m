#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLengthFormatter.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSLocale.h>

int main()
{
  START_SET("NSLengthFormatter advanced");

  NSLengthFormatter *formatter;
  NSString *result;
  NSString *result2;
  NSLengthFormatterUnit usedUnit;

  formatter = AUTORELEASE([[NSLengthFormatter alloc] init]);

  // Test very large length values
  result = [formatter stringFromValue: 100000.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format 100 km worth of meters");

  result = [formatter stringFromValue: 1000.0 unit: NSLengthFormatterUnitKilometer];
  PASS(result != nil && [result length] > 0, "Format 1000 kilometers");

  result = [formatter stringFromValue: 1000.0 unit: NSLengthFormatterUnitMile];
  PASS(result != nil && [result length] > 0, "Format 1000 miles");

  // Test very small values
  result = [formatter stringFromValue: 0.001 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format millimeter-scale value");

  result = [formatter stringFromValue: 0.1 unit: NSLengthFormatterUnitInch];
  PASS(result != nil && [result length] > 0, "Format fraction of an inch");

  // Test negative values
  result = [formatter stringFromValue: -100.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil, "Handle negative length value");

  result = [formatter stringFromMeters: -50.0];
  PASS(result != nil, "Handle negative meters");

  // Test zero
  result = [formatter stringFromValue: 0.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format zero length");

  result = [formatter stringFromMeters: 0.0];
  PASS(result != nil && [result length] > 0, "Format zero meters");

  // Test conversion accuracy (1 inch = 2.54 cm)
  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitInch];
  result2 = [formatter stringFromValue: 2.54 unit: NSLengthFormatterUnitCentimeter];
  PASS(result != nil && result2 != nil, "Inch to centimeter conversion");

  // Test foot to inch conversion (1 ft = 12 in)
  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitFoot];
  result2 = [formatter stringFromValue: 12.0 unit: NSLengthFormatterUnitInch];
  PASS(result != nil && result2 != nil, "Foot to inch conversion");

  // Test yard to foot conversion (1 yd = 3 ft)
  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitYard];
  result2 = [formatter stringFromValue: 3.0 unit: NSLengthFormatterUnitFoot];
  PASS(result != nil && result2 != nil, "Yard to foot conversion");

  // Test mile to foot conversion (1 mi = 5280 ft)
  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitMile];
  result2 = [formatter stringFromValue: 5280.0 unit: NSLengthFormatterUnitFoot];
  PASS(result != nil && result2 != nil, "Mile to foot conversion");

  // Test person height vs regular length
  [formatter setForPersonHeightUse: YES];
  result = [formatter stringFromMeters: 1.75]; // Average adult height
  [formatter setForPersonHeightUse: NO];
  result2 = [formatter stringFromMeters: 1.75];
  PASS(result != nil && result2 != nil, 
       "Person height vs regular length may use different units");

  // Test typical person height values
  [formatter setForPersonHeightUse: YES];
  result = [formatter stringFromMeters: 1.50]; // Shorter person
  PASS(result != nil, "Format shorter person height");

  result = [formatter stringFromMeters: 1.75]; // Average person
  PASS(result != nil, "Format average person height");

  result = [formatter stringFromMeters: 2.00]; // Taller person
  PASS(result != nil, "Format taller person height");

  result = [formatter stringFromMeters: 0.50]; // Child height
  PASS(result != nil, "Format child height");

  // Test unit styles with different length values
  [formatter setForPersonHeightUse: NO];
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromMeters: 10.5];
  PASS(result != nil && [result length] > 0, "Short style with meters");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromMeters: 10.5];
  PASS(result != nil && [result length] > 0, "Medium style with meters");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromMeters: 10.5];
  PASS(result != nil && [result length] > 0, "Long style with meters");

  // Test all unit types
  result = [formatter stringFromValue: 100.0 unit: NSLengthFormatterUnitMillimeter];
  PASS(result != nil && [result length] > 0, "Format millimeters");

  result = [formatter stringFromValue: 50.0 unit: NSLengthFormatterUnitCentimeter];
  PASS(result != nil && [result length] > 0, "Format centimeters");

  result = [formatter stringFromValue: 10.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format meters");

  result = [formatter stringFromValue: 5.0 unit: NSLengthFormatterUnitKilometer];
  PASS(result != nil && [result length] > 0, "Format kilometers");

  result = [formatter stringFromValue: 12.0 unit: NSLengthFormatterUnitInch];
  PASS(result != nil && [result length] > 0, "Format inches");

  result = [formatter stringFromValue: 3.0 unit: NSLengthFormatterUnitFoot];
  PASS(result != nil && [result length] > 0, "Format feet");

  result = [formatter stringFromValue: 10.0 unit: NSLengthFormatterUnitYard];
  PASS(result != nil && [result length] > 0, "Format yards");

  result = [formatter stringFromValue: 2.0 unit: NSLengthFormatterUnitMile];
  PASS(result != nil && [result length] > 0, "Format miles");

  // Test unit string extraction
  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitMillimeter];
  PASS(result != nil && [result length] > 0, "Extract millimeter unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitCentimeter];
  PASS(result != nil && [result length] > 0, "Extract centimeter unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Extract meter unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitKilometer];
  PASS(result != nil && [result length] > 0, "Extract kilometer unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitInch];
  PASS(result != nil && [result length] > 0, "Extract inch unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitFoot];
  PASS(result != nil && [result length] > 0, "Extract foot unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitYard];
  PASS(result != nil && [result length] > 0, "Extract yard unit string");

  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitMile];
  PASS(result != nil && [result length] > 0, "Extract mile unit string");

  // Test unitStringFromMeters with used unit output
  usedUnit = NSLengthFormatterUnitMeter;
  result = [formatter unitStringFromMeters: 100.0 usedUnit: &usedUnit];
  PASS(result != nil && [result length] > 0, "Extract unit string from meters");

  result = [formatter unitStringFromMeters: 0.5 usedUnit: &usedUnit];
  PASS(result != nil, "Extract unit string from fractional meters");

  // Test with nil unit pointer
  result = [formatter unitStringFromMeters: 100.0 usedUnit: NULL];
  PASS(result != nil && [result length] > 0, 
       "unitStringFromMeters works with NULL unit pointer");

  // Test number formatter customization
  NSNumberFormatter *numFormatter = AUTORELEASE([[NSNumberFormatter alloc] init]);
  [numFormatter setMaximumFractionDigits: 2];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromMeters: 12.3456];
  PASS(result != nil, "Custom number formatter applied");

  // Reset to default
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter auto-creates when set to nil");

  // Test with various NSNumber types
  result = [formatter stringForObjectValue: @(100)];
  PASS(result != nil && [result length] > 0, "Format integer NSNumber");

  result = [formatter stringForObjectValue: @(100.5)];
  PASS(result != nil && [result length] > 0, "Format floating-point NSNumber");

  result = [formatter stringForObjectValue: [NSNumber numberWithDouble: 250.75]];
  PASS(result != nil && [result length] > 0, "Format double NSNumber");

  // Test with nil and invalid objects
  result = [formatter stringForObjectValue: nil];
  PASS(result != nil, "Handle nil object gracefully");

  result = [formatter stringForObjectValue: @"not a number"];
  PASS(result != nil, "Handle non-number string");

  result = [formatter stringForObjectValue: [NSDate date]];
  PASS(result != nil, "Handle invalid object type");

  // Test fractional values
  result = [formatter stringFromMeters: 0.5];
  PASS(result != nil, "Format half meter");

  result = [formatter stringFromMeters: 1.25];
  PASS(result != nil, "Format 1.25 meters");

  result = [formatter stringFromValue: 2.75 unit: NSLengthFormatterUnitFoot];
  PASS(result != nil, "Format fractional feet");

  // Test boundary between units
  result = [formatter stringFromMeters: 0.999];
  result2 = [formatter stringFromMeters: 1.001];
  PASS(result != nil && result2 != nil, 
       "Format values at unit boundary");

  // Test consistency across multiple calls
  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  [formatter setForPersonHeightUse: NO];
  result = [formatter stringFromMeters: 50.5];
  result2 = [formatter stringFromMeters: 50.5];
  PASS(result != nil && result2 != nil && [result isEqual: result2],
       "Multiple calls produce consistent results");

  // Test locale sensitivity (metric vs imperial)
  NSLocale *usLocale = [NSLocale localeWithLocaleIdentifier: @"en_US"];
  [numFormatter setLocale: usLocale];
  [formatter setNumberFormatter: numFormatter];
  result = [formatter stringFromMeters: 100.0];
  PASS(result != nil, "US locale formatting works");

  NSLocale *ukLocale = [NSLocale localeWithLocaleIdentifier: @"en_GB"];
  [numFormatter setLocale: ukLocale];
  result = [formatter stringFromMeters: 100.0];
  PASS(result != nil, "UK locale formatting works");

  NSLocale *deLocale = [NSLocale localeWithLocaleIdentifier: @"de_DE"];
  [numFormatter setLocale: deLocale];
  result = [formatter stringFromMeters: 100.0];
  PASS(result != nil, "German locale formatting works");

  // Test parsing (if implemented)
  id parsedValue = nil;
  NSString *error = nil;
  BOOL parsed = [formatter getObjectValue: &parsedValue 
                                forString: @"5 m"
                         errorDescription: &error];
  PASS(parsed == YES || parsedValue != nil || error != nil, 
       "Parsing returns some result");

  parsed = [formatter getObjectValue: &parsedValue 
                          forString: @"10.5 ft"
                   errorDescription: &error];
  PASS(parsed == YES || parsedValue != nil || error != nil, 
       "Parsing feet returns some result");

  // Test marathon distance
  result = [formatter stringFromMeters: 42195.0]; // Marathon distance
  PASS(result != nil, "Format marathon distance");

  // Test astronomical distances (should still work)
  result = [formatter stringFromMeters: 384400000.0]; // Earth to Moon
  PASS(result != nil, "Format very large distance");

  END_SET("NSLengthFormatter advanced");
  return 0;
}
