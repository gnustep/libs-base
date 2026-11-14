#import <Foundation/Foundation.h>
#import "Testing.h"
#include <math.h>
#include <stdlib.h>

/* -scanDouble: keeps 18 significant digits of the mantissa and ignores the
   rest.  Integer digits it ignored must still count towards the magnitude. */

static BOOL
matchesStrtod(const char *text)
{
  NSString	*s = [NSString stringWithUTF8String: text];
  NSScanner	*sc = [NSScanner scannerWithString: s];
  double	scanned = 0.0;
  double	expected = strtod(text, NULL);

  if (NO == [sc scanDouble: &scanned])
    {
      return NO;
    }
  if (fabs(scanned - expected) > fabs(expected) * 1e-15)
    {
      return NO;
    }
  return [sc isAtEnd];
}

int main(void)
{
  START_SET("NSScanner scanDouble: long mantissas")
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSScanner		*sc;
  double		d = 0.0;

  PASS(matchesStrtod("999999999999999999"),
    "18 integer digits, nothing ignored")
  PASS(matchesStrtod("1234567890123456789"),
    "19 integer digits")
  PASS(matchesStrtod("18446744073709551616"),
    "20 integer digits")
  PASS(matchesStrtod("123456789012345678901"),
    "21 integer digits")
  PASS(matchesStrtod("1000000000000000000000"),
    "22 integer digits, ignored digits all zero")
  PASS(matchesStrtod("-18446744073709551616"),
    "a negative value keeps its magnitude")
  PASS(matchesStrtod("00018446744073709551616"),
    "leading zeros do not count as digits")
  PASS(matchesStrtod("18446744073709551616.5"),
    "ignored integer digits before a decimal point")
  PASS(matchesStrtod("1234567890123456789012.5"),
    "several ignored integer digits before a decimal point")
  PASS(matchesStrtod("123456789012345678.5"),
    "18 integer digits and a fraction")
  PASS(matchesStrtod("0.12345678901234567890123"),
    "ignored digits in the fraction do not change the magnitude")
  PASS(matchesStrtod("1234567890.1234567890123"),
    "ignored digits after the decimal point")
  PASS(matchesStrtod("18446744073709551616e2"),
    "ignored integer digits with a positive exponent")
  PASS(matchesStrtod("18446744073709551616e-2"),
    "ignored integer digits with a negative exponent")

  sc = [NSScanner scannerWithString: @"18446744073709551616"];
  PASS([sc scanDouble: &d] && fabs(d - 1.8446744073709552e19) < 1e5,
    "scanDouble: gives the value in the original report")
  PASS(fabs([@"18446744073709551616" doubleValue] - 1.8446744073709552e19)
    < 1e5, "-[NSString doubleValue] gives the same value")

  [pool release];
  END_SET("NSScanner scanDouble: long mantissas")
  return 0;
}
