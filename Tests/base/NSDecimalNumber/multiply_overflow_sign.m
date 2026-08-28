/*
 * multiply_overflow_sign.m - regression test for NSDecimalMultiply reporting a
 * too-large product as NSCalculationUnderflow when the result is negative.
 *
 * A product whose exponent exceeds the representable range is too large to
 * represent, which is an overflow.  NSDecimalMultiply classified that case by
 * the sign of the result and returned NSCalculationUnderflow for a negative
 * product, although its magnitude is far too large (underflow is for values too
 * close to zero).  The sibling NSDecimalMultiplyByPowerOf10 already reports
 * NSCalculationOverflow for such a value regardless of sign.
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
  START_SET("NSDecimalMultiply overflow does not depend on sign")
    NSDecimal		a, pos, neg, r;
    NSCalculationError	e;

    /* Exponents sum to 200, beyond the representable range, so the product is
     * too large whichever sign it carries. */
    a = dfs("5e100");
    pos = dfs("5e100");
    neg = dfs("-5e100");

    e = NSDecimalMultiply(&r, &a, &pos, NSRoundPlain);
    PASS(e == NSCalculationOverflow,
      "a large positive product reports overflow");
    e = NSDecimalMultiply(&r, &a, &neg, NSRoundPlain);
    PASS(e == NSCalculationOverflow,
      "a large negative product reports overflow, not underflow");

    /* NSDecimalMultiplyByPowerOf10 classifies the same magnitude the same way. */
    e = NSDecimalMultiplyByPowerOf10(&r, &neg, 100, NSRoundPlain);
    PASS(e == NSCalculationOverflow,
      "NSDecimalMultiplyByPowerOf10 agrees for a large negative value");
  END_SET("NSDecimalMultiply overflow does not depend on sign")

  return 0;
}
