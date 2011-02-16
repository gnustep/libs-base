#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  NSAutoreleasePool   *arp = [NSAutoreleasePool new];
  NSNumberFormatter *fmt;
  NSNumber *num;
  NSString *str;
  
  [NSNumberFormatter setDefaultFormatterBehavior: NSNumberFormatterBehavior10_0];

  TEST_FOR_CLASS(@"NSNumberFormatter",[NSNumberFormatter alloc],
                 "+[NSNumberFormatter alloc] returns a NSNumberFormatter");

  fmt = [[[NSNumberFormatter alloc] init] autorelease];
  num = [[[NSNumber alloc] initWithFloat: 1234.567] autorelease];

  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"1,234.57", "default format same as Cocoa");

  [fmt setAllowsFloats: NO];
  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"1,235", "round up for fractional part >0.5");

  num = [[[NSNumber alloc] initWithFloat: 1234.432] autorelease];
  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"1,234", "round down for fractional part <0.5");

  [fmt setFormat: @"__000000"];
  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"  001234", "numeric and space padding OK");

  num = [[[NSNumber alloc] initWithFloat: 1234.56] autorelease];
  [fmt setAllowsFloats: YES];
  [fmt setPositiveFormat: @"$####.##c"];
  [fmt setNegativeFormat: @"-$(####.##)"];
  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"$1234.56c", "prefix and suffix used properly");

  num = [[[NSNumber alloc] initWithFloat: -1234.56] autorelease];
  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"-$(1234.56)", "negativeFormat used for -ve number");

  str = [fmt stringForObjectValue: [NSDecimalNumber notANumber]];

  PASS_EQUAL(str, @"NaN", "notANumber special case");

  [fmt setFormat: @"0"];
  str = [fmt stringForObjectValue: num];

  PASS_EQUAL(str, @"-1235", "format string of length 1");

  [arp release]; arp = nil;
  return 0;
}

