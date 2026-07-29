/*
 * decimal_functions.m - coverage tests for the NSDecimal C functions declared
 * in Foundation/NSDecimal.h: construction (NSDecimalFromString,
 * NSDecimalFromComponents), formatting (NSDecimalString), the arithmetic
 * operations (Add, Subtract, Multiply, Divide, Power, MultiplyByPowerOf10),
 * NSDecimalRound in every rounding mode, NSDecimalCompare, and the
 * NSDecimalCopy / NSDecimalNormalize / NSDecimalMax / NSDecimalMin /
 * NSDecimalDouble / NSDecimalIsNotANumber helpers.
 *
 * These are portable, deterministic computations; NSDecimalString is called
 * with a nil locale, which uses '.' as the decimal separator.
 */

#import <Foundation/Foundation.h>
#import <Foundation/NSDecimal.h>
#import "ObjectTesting.h"

/* Format a decimal with the default (locale-independent) separator. */
static NSString *
dstr(NSDecimal d)
{
  return NSDecimalString(&d, nil);
}

/* Build a decimal from a C string. */
static NSDecimal
dfs(const char *s)
{
  NSDecimal d;

  NSDecimalFromString(&d, [NSString stringWithUTF8String: s], nil);
  return d;
}

int main(void)
{
  START_SET("NSDecimalFromString and NSDecimalString")
    PASS_EQUAL(dstr(dfs("1.5")), @"1.5",
      "a fractional value round-trips through string conversion");
    PASS_EQUAL(dstr(dfs("0")), @"0.0", "zero formats as 0.0");
    PASS_EQUAL(dstr(dfs("-42.25")), @"-42.25", "a negative value keeps its sign");
    PASS_EQUAL(dstr(dfs("100")), @"100", "an integer value has no fraction");
    PASS_EQUAL(dstr(dfs("0.015")), @"0.015", "a small value keeps leading zeros");
  END_SET("NSDecimalFromString and NSDecimalString")

  START_SET("NSDecimalFromComponents")
    NSDecimal	d;

    NSDecimalFromComponents(&d, 15, -1, NO);
    PASS_EQUAL(dstr(d), @"1.5", "mantissa 15 exponent -1 is 1.5");
    NSDecimalFromComponents(&d, 5, 2, NO);
    PASS_EQUAL(dstr(d), @"500", "mantissa 5 exponent 2 is 500");
    NSDecimalFromComponents(&d, 123, 0, YES);
    PASS_EQUAL(dstr(d), @"-123", "the negative flag is honoured");
  END_SET("NSDecimalFromComponents")

  START_SET("NSDecimalAdd and NSDecimalSubtract")
    NSDecimal		a, b, r;
    NSCalculationError	e;

    a = dfs("2"); b = dfs("3");
    e = NSDecimalAdd(&r, &a, &b, NSRoundPlain);
    PASS(e == NSCalculationNoError, "NSDecimalAdd reports no error");
    PASS_EQUAL(dstr(r), @"5", "2 + 3 == 5");

    a = dfs("0.1"); b = dfs("0.2");
    NSDecimalAdd(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"0.3", "0.1 + 0.2 == 0.3 exactly");

    a = dfs("-5"); b = dfs("3");
    NSDecimalAdd(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"-2", "-5 + 3 == -2");

    a = dfs("5"); b = dfs("3");
    NSDecimalSubtract(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"2", "5 - 3 == 2");

    a = dfs("3"); b = dfs("5");
    NSDecimalSubtract(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"-2", "3 - 5 == -2");

    a = dfs("0.3"); b = dfs("0.1");
    NSDecimalSubtract(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"0.2", "0.3 - 0.1 == 0.2 exactly");
  END_SET("NSDecimalAdd and NSDecimalSubtract")

  START_SET("NSDecimalMultiply")
    NSDecimal	a, b, r;

    a = dfs("3"); b = dfs("4");
    NSDecimalMultiply(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"12", "3 * 4 == 12");

    a = dfs("1.5"); b = dfs("2");
    NSDecimalMultiply(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"3", "1.5 * 2 == 3");

    a = dfs("-2"); b = dfs("3");
    NSDecimalMultiply(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"-6", "a single negative operand gives a negative product");

    a = dfs("0.1"); b = dfs("0.1");
    NSDecimalMultiply(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"0.01", "0.1 * 0.1 == 0.01");
  END_SET("NSDecimalMultiply")

  START_SET("NSDecimalDivide")
    NSDecimal		a, b, r;
    NSCalculationError	e;

    a = dfs("6"); b = dfs("2");
    NSDecimalDivide(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"3", "6 / 2 == 3");

    a = dfs("1"); b = dfs("4");
    NSDecimalDivide(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"0.25", "1 / 4 == 0.25");

    a = dfs("0"); b = dfs("5");
    NSDecimalDivide(&r, &a, &b, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"0.0", "0 / 5 == 0");

    a = dfs("1"); b = dfs("3");
    e = NSDecimalDivide(&r, &a, &b, NSRoundPlain);
    PASS(e == NSCalculationLossOfPrecision,
      "1 / 3 reports loss of precision");
    PASS(NSDecimalDouble(&r) > 0.33333 && NSDecimalDouble(&r) < 0.33334,
      "1 / 3 is approximately 0.3333");

    a = dfs("10"); b = dfs("0");
    e = NSDecimalDivide(&r, &a, &b, NSRoundPlain);
    PASS(e == NSCalculationDivideByZero,
      "division by zero reports NSCalculationDivideByZero");
    PASS(NSDecimalIsNotANumber(&r) == YES,
      "division by zero yields a not-a-number result");
  END_SET("NSDecimalDivide")

  START_SET("NSDecimalPower")
    NSDecimal	a, r;

    a = dfs("2"); NSDecimalPower(&r, &a, 10, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"1024", "2 ^ 10 == 1024");
    a = dfs("5"); NSDecimalPower(&r, &a, 0, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"1", "any base ^ 0 == 1");
    a = dfs("10"); NSDecimalPower(&r, &a, 3, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"1000", "10 ^ 3 == 1000");
    a = dfs("-2"); NSDecimalPower(&r, &a, 2, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"4", "a negative base to an even power is positive");
    a = dfs("-2"); NSDecimalPower(&r, &a, 3, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"-8", "a negative base to an odd power is negative");
  END_SET("NSDecimalPower")

  START_SET("NSDecimalMultiplyByPowerOf10")
    NSDecimal	a, r;

    a = dfs("5"); NSDecimalMultiplyByPowerOf10(&r, &a, 2, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"500", "5 * 10^2 == 500");
    a = dfs("5"); NSDecimalMultiplyByPowerOf10(&r, &a, -1, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"0.5", "5 * 10^-1 == 0.5");
  END_SET("NSDecimalMultiplyByPowerOf10")

  START_SET("NSDecimalRound")
    NSDecimal	a, r;

    a = dfs("1.5"); NSDecimalRound(&r, &a, 0, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"2", "NSRoundPlain rounds 1.5 up to 2");
    a = dfs("1.5"); NSDecimalRound(&r, &a, 0, NSRoundDown);
    PASS_EQUAL(dstr(r), @"1", "NSRoundDown rounds 1.5 down to 1");
    a = dfs("1.5"); NSDecimalRound(&r, &a, 0, NSRoundUp);
    PASS_EQUAL(dstr(r), @"2", "NSRoundUp rounds 1.5 up to 2");
    a = dfs("1.5"); NSDecimalRound(&r, &a, 0, NSRoundBankers);
    PASS_EQUAL(dstr(r), @"2", "NSRoundBankers rounds 1.5 to the even 2");
    a = dfs("2.5"); NSDecimalRound(&r, &a, 0, NSRoundBankers);
    PASS_EQUAL(dstr(r), @"2", "NSRoundBankers rounds 2.5 to the even 2");
    a = dfs("1.25"); NSDecimalRound(&r, &a, 1, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"1.3", "rounding to scale 1 keeps one fraction digit");
    a = dfs("-1.5"); NSDecimalRound(&r, &a, 0, NSRoundPlain);
    PASS_EQUAL(dstr(r), @"-2", "NSRoundPlain rounds -1.5 away from zero to -2");
  END_SET("NSDecimalRound")

  START_SET("NSDecimalCompare")
    NSDecimal	a, b;

    a = dfs("1"); b = dfs("2");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedAscending, "1 < 2");
    a = dfs("2"); b = dfs("1");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedDescending, "2 > 1");
    a = dfs("1"); b = dfs("1");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedSame, "1 == 1");
    a = dfs("-1"); b = dfs("1");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedAscending, "-1 < 1");
    a = dfs("1.0"); b = dfs("1.00");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedSame,
      "values differing only in trailing zeros compare equal");
  END_SET("NSDecimalCompare")

  START_SET("NSDecimalCopy, Normalize, Max, Min, Double")
    NSDecimal	a, b, r, big;

    a = dfs("1.5");
    NSDecimalCopy(&r, &a);
    PASS(NSDecimalCompare(&r, &a) == NSOrderedSame,
      "NSDecimalCopy produces an equal value");

    a = dfs("1.5"); b = dfs("2.05");
    NSDecimalNormalize(&a, &b, NSRoundPlain);
    PASS(a.exponent == b.exponent,
      "NSDecimalNormalize gives both operands the same exponent");
    PASS(NSDecimalDouble(&a) > 1.49999 && NSDecimalDouble(&a) < 1.50001
      && NSDecimalDouble(&b) > 2.04999 && NSDecimalDouble(&b) < 2.05001,
      "NSDecimalNormalize preserves both values");

    big = dfs("1000000");
    NSDecimalMax(&r);
    PASS(NSDecimalCompare(&r, &big) == NSOrderedDescending,
      "NSDecimalMax is larger than an ordinary number");
    NSDecimalMin(&r);
    PASS(NSDecimalCompare(&r, &big) == NSOrderedAscending,
      "NSDecimalMin is smaller than an ordinary number");

    a = dfs("1.5");
    PASS(NSDecimalDouble(&a) > 1.49999 && NSDecimalDouble(&a) < 1.50001,
      "NSDecimalDouble returns the value as a double");
  END_SET("NSDecimalCopy, Normalize, Max, Min, Double")

  return 0;
}
