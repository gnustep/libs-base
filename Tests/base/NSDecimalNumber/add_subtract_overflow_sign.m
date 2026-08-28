/*
 * add_subtract_overflow_sign.m - regression test for NSDecimalAdd and
 * NSDecimalSubtract classifying an out-of-range result by its sign.  Two large
 * negatives summed to an even larger magnitude were reported as
 * NSCalculationUnderflow, while the positive counterpart was reported as
 * NSCalculationOverflow; underflow is for values too close to zero, so a value
 * that large must not be an underflow, and the error must not depend on sign.
 *
 * Whether the overflow is detected at all depends on the build (the GMP mantissa
 * code does not flag it), so the test asserts that the two signs agree and that
 * neither is reported as underflow, rather than a specific error code.
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
  START_SET("NSDecimalAdd/Subtract overflow does not depend on sign")
    NSDecimal		pos, neg, r;
    NSCalculationError	ep, en;

    /* 38 nines * 10^126: adding two of these carries the exponent to 127. */
    pos = dfs("99999999999999999999999999999999999999e126");
    neg = dfs("-99999999999999999999999999999999999999e126");

    ep = NSDecimalAdd(&r, &pos, &pos, NSRoundPlain);
    en = NSDecimalAdd(&r, &neg, &neg, NSRoundPlain);
    PASS(en != NSCalculationUnderflow,
      "a large negative sum is not reported as underflow");
    PASS(ep == en,
      "the sum error does not depend on the sign of the result");

    /* (+big) - (-big) and (-big) - (+big) reach the same magnitude. */
    ep = NSDecimalSubtract(&r, &pos, &neg, NSRoundPlain);
    en = NSDecimalSubtract(&r, &neg, &pos, NSRoundPlain);
    PASS(en != NSCalculationUnderflow,
      "a large negative difference is not reported as underflow");
    PASS(ep == en,
      "the difference error does not depend on the sign of the result");
  END_SET("NSDecimalAdd/Subtract overflow does not depend on sign")

  return 0;
}
