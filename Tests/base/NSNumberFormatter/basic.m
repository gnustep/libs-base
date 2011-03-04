#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  START_SET("basic")

    NSNumberFormatter *fmt;
    NSNumber *num;
    
    [NSNumberFormatter
      setDefaultFormatterBehavior: NSNumberFormatterBehavior10_0];

    TEST_FOR_CLASS(@"NSNumberFormatter",[NSNumberFormatter alloc],
     "+[NSNumberFormatter alloc] returns a NSNumberFormatter");

    fmt = [[[NSNumberFormatter alloc] init] autorelease];
    num = [[[NSNumber alloc] initWithFloat: 1234.567] autorelease];

    PASS_EQUAL([fmt stringForObjectValue: num], @"1,234.57",
      "default format same as Cocoa")

    num = [[[NSNumber alloc] initWithFloat: 1.01] autorelease];
    PASS_EQUAL([fmt stringFromNumber: num], @"1.01",
      "Handle leading zeroes in fractional part: 1.01")

    [fmt setAllowsFloats: NO];
    num = [[[NSNumber alloc] initWithFloat: 1234.567] autorelease];
    PASS_EQUAL([fmt stringForObjectValue: num], @"1,235",
      "round up for fractional part >0.5")

    num = [[[NSNumber alloc] initWithFloat: 1234.432] autorelease];
    PASS_EQUAL([fmt stringForObjectValue: num], @"1,234",
      "round down for fractional part <0.5")

    [fmt setFormat: @"__000000"];
    PASS_EQUAL([fmt stringForObjectValue: num], @"  001234",
      "numeric and space padding OK")

    num = [[[NSNumber alloc] initWithFloat: 1234.56] autorelease];
    [fmt setAllowsFloats: YES];
    [fmt setPositiveFormat: @"$####.##c"];
    [fmt setNegativeFormat: @"-$(####.##)"];
    PASS_EQUAL([fmt stringForObjectValue: num], @"$1234.56c",
      "prefix and suffix used properly")

    num = [[[NSNumber alloc] initWithFloat: -1234.56] autorelease];
    PASS_EQUAL([fmt stringForObjectValue: num], @"-$(1234.56)",
      "negativeFormat used for -ve number")

    PASS_EQUAL([fmt stringForObjectValue: [NSDecimalNumber notANumber]], 
      @"NaN", "notANumber special case")

    [fmt setFormat: @"0"];
    PASS_EQUAL([fmt stringForObjectValue: num], @"-1235",
      "format string of length 1")

  END_SET("basic")

  return 0;
}

