/*
 * compare_trailing_zeros.m - regression test for NSDecimalCompare treating a
 * mantissa that carries trailing zeros as a different value from the same
 * number without them.
 *
 * NSDecimalNormalize aligns the exponents of two decimals, appending trailing
 * zeros to the mantissa of the operand with the larger exponent (1.5 becomes
 * 1.50 when normalized against 2.05).  GSDecimalCompare broke the tie between
 * two values with equal leading digits purely on mantissa length, so the
 * normalized 1.50 compared as greater than 1.5 although they are equal.  A
 * trailing zero is not significant, so the two must compare NSOrderedSame.
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

/* Return "value" carrying trailing zeros, by normalizing it against a value
 * with a smaller exponent (which pads "value" without changing it). */
static NSDecimal
padded(const char *value, const char *other)
{
  NSDecimal a = dfs(value);
  NSDecimal b = dfs(other);

  NSDecimalNormalize(&a, &b, NSRoundPlain);
  return a;
}

int main(void)
{
  START_SET("NSDecimalCompare ignores trailing zeros")
    NSDecimal	p, q, a, b;

    /* 1.5 normalized against 2.05 becomes 1.50 (mantissa 150, exponent -2). */
    p = padded("1.5", "2.05");
    a = dfs("1.5");
    PASS(NSDecimalCompare(&p, &a) == NSOrderedSame,
      "1.50 (padded) compares equal to 1.5");
    PASS(NSDecimalCompare(&a, &p) == NSOrderedSame,
      "1.5 compares equal to 1.50 (padded)");

    /* Same for negative values. */
    q = padded("-1.5", "-2.05");
    b = dfs("-1.5");
    PASS(NSDecimalCompare(&q, &b) == NSOrderedSame,
      "-1.50 (padded) compares equal to -1.5");

    /* Positive controls: a genuine trailing digit still orders correctly. */
    a = dfs("1.53"); b = dfs("1.5");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedDescending,
      "1.53 is still greater than 1.5");
    a = dfs("2"); b = dfs("1");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedDescending,
      "2 is still greater than 1");
    a = dfs("1.5"); b = dfs("1.5");
    PASS(NSDecimalCompare(&a, &b) == NSOrderedSame,
      "1.5 compares equal to itself");
  END_SET("NSDecimalCompare ignores trailing zeros")

  return 0;
}
