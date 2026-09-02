#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMassFormatter.h>

int main()
{
  START_SET("NSMassFormatter format validation");

  NSMassFormatter *formatter;
  NSString *result;

  formatter = AUTORELEASE([[NSMassFormatter alloc] init]);
  
  // Test that format includes both number and unit
  result = [formatter stringFromKilograms: 1.0];
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       ([result rangeOfString: @"kg"].location != NSNotFound ||
        [result rangeOfString: @"kilogram"].location != NSNotFound),
       "1 kg format includes number and unit");

  // Test gram formatting
  result = [formatter stringFromValue: 500.0 unit: NSMassFormatterUnitGram];
  PASS([result rangeOfString: @"500"].location != NSNotFound &&
       ([result rangeOfString: @"g"].location != NSNotFound ||
        [result rangeOfString: @"gram"].location != NSNotFound),
       "500 g format correct");

  // Test pound formatting
  result = [formatter stringFromValue: 10.0 unit: NSMassFormatterUnitPound];
  PASS([result rangeOfString: @"10"].location != NSNotFound &&
       ([result rangeOfString: @"lb"].location != NSNotFound ||
        [result rangeOfString: @"pound"].location != NSNotFound),
       "10 lb format correct");

  // Test unit style Short
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromKilograms: 2.5];
  PASS([result rangeOfString: @"2"].location != NSNotFound ||
       [result rangeOfString: @"3"].location != NSNotFound,
       "Short style shows number");

  // Test unit style Long includes full word
  [formatter setUnitStyle: NSFormattingUnitStyleLong];
  result = [formatter stringFromKilograms: 1.0];
  PASS([result rangeOfString: @"kilogram"].location != NSNotFound ||
       [result rangeOfString: @"kg"].location != NSNotFound,
       "Long style shows unit name");

  // Test zero handling
  result = [formatter stringFromKilograms: 0.0];
  PASS([result rangeOfString: @"0"].location != NSNotFound,
       "Zero kg shows 0");

  // Test fractional values
  result = [formatter stringFromKilograms: 1.5];
  PASS([result rangeOfString: @"1"].location != NSNotFound ||
       [result rangeOfString: @"2"].location != NSNotFound,
       "1.5 kg formats correctly");

  END_SET("NSMassFormatter format validation");
  return 0;
}
