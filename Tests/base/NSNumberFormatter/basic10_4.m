#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  NSNumberFormatter *fmt;
  NSNumber *num;
  NSString *str;

  START_SET(YES)

  fmt = [[[NSNumberFormatter alloc] init] autorelease];
  num = [[[NSNumber alloc] initWithFloat: 1234.567] autorelease];

  str = [fmt stringFromNumber: num];
  PASS_EQUAL(str, @"1235", "default 10.4 format same as Cocoa");

  [fmt setMaximumFractionDigits: 2];
  str = [fmt stringFromNumber: num];

  PASS_EQUAL(str, @"1234.57", "round up for fractional part >0.5");

  num = [[[NSNumber alloc] initWithFloat: 1234.432] autorelease];
  str = [fmt stringFromNumber: num];

  PASS_EQUAL(str, @"1234.43", "round down for fractional part <0.5");

  [fmt setNumberStyle: NSNumberFormatterNoStyle];
  [fmt setMaximumFractionDigits: 0];
  [fmt setFormatWidth: 6];
  [fmt setPositivePrefix: @"+"];
  [fmt setPaddingCharacter: @"0"];
  [fmt setPaddingPosition: NSNumberFormatterPadBeforePrefix];
  str = [fmt stringFromNumber: num];
  
  PASS_EQUAL(str, @"0+1234", "numeric and space padding OK");

  num = [[[NSNumber alloc] initWithFloat: 1234.56] autorelease];
  [fmt setNumberStyle: NSNumberFormatterCurrencyStyle];
  [fmt setLocale: [[NSLocale alloc] initWithLocaleIdentifier: @"pt_BR"]];
  [fmt setPositiveSuffix: @"c"];
  str = [fmt stringFromNumber: num];
  
  PASS_EQUAL(str, @"R$1.235c", "prefix and suffix used properly");

  num = [[[NSNumber alloc] initWithFloat: -1234.56] autorelease];
  str = [fmt stringFromNumber: num];

  PASS_EQUAL(str, @"(R$1.235)", "negativeFormat used for -ve number");

  str = [fmt stringFromNumber: [NSDecimalNumber notANumber]];

  PASS_EQUAL(str, @"NaN", "notANumber special case");

  [fmt setNumberStyle: NSNumberFormatterNoStyle];
  [fmt setMaximumFractionDigits: 0];
  str = [fmt stringFromNumber: num];
  
  PASS_EQUAL(str, @"-1235", "format string of length 1");

  num = nil;
  PASS_RUNS(({[fmt getObjectValue: &num forString: @"0.00" errorDescription: &str];}),
    "getObjectValue:forString:errorDescription: runs")
  PASS_EQUAL(num,  [NSNumber numberWithFloat: 0.0],
    "getObjectValue inited with 0.00")
  END_SET("NSNumberFormatter 10.4")

  return 0;
}

