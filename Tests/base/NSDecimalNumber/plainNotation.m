#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDecimalNumber.h>
#import <Foundation/NSDictionary.h>

static NSString *
text(NSString *s)
{
  NSDictionary  *locale = [NSDictionary dictionaryWithObject: @"."
                                                      forKey: NSDecimalSeparator];

  return [[NSDecimalNumber decimalNumberWithString: s locale: locale]
    descriptionWithLocale: locale];
}

int main()
{
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];

  START_SET("NSDecimalNumber plain notation")
  PASS_EQUAL(text(@"0"), @"0", "zero is 0");
  PASS_EQUAL(text(@"0.00"), @"0", "zero with a scale is 0");
  PASS_EQUAL(text(@"-0.5"), @"-0.5", "a negative fraction");
  PASS_EQUAL(text(@"1234567"), @"1234567", "seven digits are written out");
  PASS_EQUAL(text(@"100000000000000000000"), @"100000000000000000000",
    "a large number is written out");
  PASS_EQUAL(text(@"1E7"), @"10000000", "a number read with an exponent is written out");
  PASS_EQUAL(text(@"0.0001234"), @"0.0001234", "a small fraction is written out");
  PASS_EQUAL(text(@"1.5E-8"), @"0.000000015", "a tiny fraction is written out");
  PASS_EQUAL(text(@"1234567.891"), @"1234567.891", "a large number with a fraction");
  END_SET("NSDecimalNumber plain notation")

  [arp release];
  return 0;
}
