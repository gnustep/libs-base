/*
 * nan_and_edges.m - coverage for NSDecimal edge cases that decimal_functions.m
 * does not reach: propagation of a not-a-number operand through the arithmetic
 * and comparison functions, the overflow/underflow returns of
 * NSDecimalMultiplyByPowerOf10, boundary cases of NSDecimalPower, and
 * NSDecimalCompact.
 */

#import <Foundation/Foundation.h>
#import <Foundation/NSDecimal.h>
#import "ObjectTesting.h"

static NSDecimal
dfs(const char *s)
{
  NSDecimal d;

  NSDecimalFromString(&d, [NSString stringWithUTF8String: s], nil);
  return d;
}

int main(void)
{
  START_SET("a not-a-number operand propagates")
    NSDecimal		nan, five, r;
    NSDecimal		ten = dfs("10"), z = dfs("0");

    /* Division by zero is the way to obtain a not-a-number value. */
    NSDecimalDivide(&nan, &ten, &z, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&nan), "10 / 0 is not a number");
    five = dfs("5");

    NSDecimalAdd(&r, &nan, &five, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "nan + 5 is not a number");
    NSDecimalAdd(&r, &five, &nan, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "5 + nan is not a number");
    NSDecimalSubtract(&r, &five, &nan, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "5 - nan is not a number");
    NSDecimalMultiply(&r, &nan, &five, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "nan * 5 is not a number");
    NSDecimalDivide(&r, &nan, &five, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "nan / 5 is not a number");
    NSDecimalPower(&r, &nan, 2, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "nan ^ 2 is not a number");
    NSDecimalMultiplyByPowerOf10(&r, &nan, 3, NSRoundPlain);
    PASS(NSDecimalIsNotANumber(&r), "nan * 10^3 is not a number");
  END_SET("a not-a-number operand propagates")

  START_SET("NSDecimalCompare orders a not-a-number value")
    NSDecimal	nan, five;
    NSDecimal	ten = dfs("10"), z = dfs("0");

    NSDecimalDivide(&nan, &ten, &z, NSRoundPlain);
    five = dfs("5");
    PASS(NSDecimalCompare(&nan, &nan) == NSOrderedSame,
      "a not-a-number value compares equal to itself");
    PASS(NSDecimalCompare(&nan, &five) == NSOrderedDescending,
      "a not-a-number value sorts above an ordinary number");
    PASS(NSDecimalCompare(&five, &nan) == NSOrderedAscending,
      "an ordinary number sorts below a not-a-number value");
  END_SET("NSDecimalCompare orders a not-a-number value")

  START_SET("NSDecimalMultiplyByPowerOf10 range")
    NSDecimal		a, r;
    NSCalculationError	e;

    a = dfs("42");
    e = NSDecimalMultiplyByPowerOf10(&r, &a, 0, NSRoundPlain);
    PASS(e == NSCalculationNoError && NSDecimalCompare(&r, &a) == NSOrderedSame,
      "scaling by 10^0 is the identity");

    a = dfs("5e100");
    e = NSDecimalMultiplyByPowerOf10(&r, &a, 100, NSRoundPlain);
    PASS(e == NSCalculationOverflow, "scaling past 10^127 overflows");

    a = dfs("5e-100");
    e = NSDecimalMultiplyByPowerOf10(&r, &a, -100, NSRoundPlain);
    PASS(e == NSCalculationUnderflow, "scaling below 10^-128 underflows");
  END_SET("NSDecimalMultiplyByPowerOf10 range")

  START_SET("NSDecimalPower boundary cases")
    NSDecimal	a, r, expected;

    a = dfs("5"); NSDecimalPower(&r, &a, 1, NSRoundPlain);
    expected = dfs("5");
    PASS(NSDecimalCompare(&r, &expected) == NSOrderedSame, "x ^ 1 == x");

    a = dfs("0"); NSDecimalPower(&r, &a, 5, NSRoundPlain);
    expected = dfs("0");
    PASS(NSDecimalCompare(&r, &expected) == NSOrderedSame, "0 ^ 5 == 0");

    a = dfs("0"); NSDecimalPower(&r, &a, 0, NSRoundPlain);
    expected = dfs("1");
    PASS(NSDecimalCompare(&r, &expected) == NSOrderedSame, "0 ^ 0 == 1");

    a = dfs("1"); NSDecimalPower(&r, &a, 1000, NSRoundPlain);
    expected = dfs("1");
    PASS(NSDecimalCompare(&r, &expected) == NSOrderedSame, "1 ^ 1000 == 1");
  END_SET("NSDecimalPower boundary cases")

  START_SET("NSDecimalCompact removes trailing zeros")
    NSDecimal	c, expected;

    /* 1500 x 10^-1 == 150, stored with a trailing zero until compacted. */
    NSDecimalFromComponents(&c, 1500, -1, NO);
    NSDecimalCompact(&c);
    expected = dfs("150");
    PASS(NSDecimalCompare(&c, &expected) == NSOrderedSame,
      "compacting keeps the value");
    PASS_EQUAL(NSDecimalString(&c, nil), @"150",
      "compacting drops the redundant trailing zero");
  END_SET("NSDecimalCompact removes trailing zeros")

  return 0;
}
