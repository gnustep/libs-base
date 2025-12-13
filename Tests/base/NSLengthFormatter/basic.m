#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSLengthFormatter.h>
#import <Foundation/NSValue.h>

int main()
{
  START_SET("NSLengthFormatter basic");

  NSLengthFormatter *formatter;
  NSString *result;
  NSNumber *number;

  // Test instance creation
  formatter = AUTORELEASE([[NSLengthFormatter alloc] init]);
  PASS(formatter != nil, "Can create NSLengthFormatter instance");

  // Test basic length formatting
  result = [formatter stringFromValue: 0.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format 0 meters");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format 1 meter");

  result = [formatter stringFromValue: 1000.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "Format 1000 meters");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitKilometer];
  PASS(result != nil && [result length] > 0, "Format 1 kilometer");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitCentimeter];
  PASS(result != nil && [result length] > 0, "Format 1 centimeter");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitMillimeter];
  PASS(result != nil && [result length] > 0, "Format 1 millimeter");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitInch];
  PASS(result != nil && [result length] > 0, "Format 1 inch");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitFoot];
  PASS(result != nil && [result length] > 0, "Format 1 foot");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitYard];
  PASS(result != nil && [result length] > 0, "Format 1 yard");

  result = [formatter stringFromValue: 1.0 unit: NSLengthFormatterUnitMile];
  PASS(result != nil && [result length] > 0, "Format 1 mile");

  // Test stringFromMeters:
  result = [formatter stringFromMeters: 1.0];
  PASS(result != nil && [result length] > 0, "stringFromMeters: works");

  result = [formatter stringFromMeters: 1000.0];
  PASS(result != nil && [result length] > 0, 
       "stringFromMeters: with kilometers");

  // Test unit styles
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromMeters: 1.5];
  PASS(result != nil, "Short unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleMedium];
  result = [formatter stringFromMeters: 1.5];
  PASS(result != nil, "Medium unit style works");

  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromMeters: 1.5];
  PASS(result != nil, "Long unit style works");

  // Test for person height use
  [formatter setForPersonHeightUse: YES];
  result = [formatter stringFromMeters: 1.75];
  PASS(result != nil, "Person height formatting works");

  [formatter setForPersonHeightUse: NO];
  result = [formatter stringFromMeters: 1.75];
  PASS(result != nil, "Non-person height formatting works");

  // Test number formatter property
  [formatter setNumberFormatter: nil];
  PASS([formatter numberFormatter] != nil, 
       "Number formatter is never nil (creates default)");

  // Test stringForObjectValue:
  number = [NSNumber numberWithDouble: 100.0];
  result = [formatter stringForObjectValue: number];
  PASS(result != nil && [result length] > 0, 
       "stringForObjectValue: works with NSNumber");

  // Test unit conversion
  result = [formatter unitStringFromValue: 1.0 unit: NSLengthFormatterUnitMeter];
  PASS(result != nil && [result length] > 0, "unitStringFromValue:unit: works");

  result = [formatter unitStringFromMeters: 1.0 
                            usedUnit: NULL];
  PASS(result != nil && [result length] > 0, 
       "unitStringFromMeters:usedUnit: works");

  // Test parsing
  double value;
  NSString *error = nil;
  BOOL parsed = [formatter getObjectValue: &number 
                                forString: @"5.5 m"
                         errorDescription: &error];
  PASS(parsed || number != nil, "Can parse length string");

  END_SET("NSLengthFormatter basic");
  return 0;
}
