/*
 * mantissa_overflow.m - regression tests for two NSDecimal operations that
 * wrote one element past the fixed cMantissa[] array on a maximum-length
 * (38-digit) value.
 *
 *  - GSSimpleAdd: adding two full 38-digit mantissas carries out to a 39th
 *    digit; the length==38 guard called NSDecimalRound with a scale that made
 *    the round a no-op, so the carry-shift wrote past cMantissa[].
 *  - GSDecimalRound: rounding a full 38-digit value at a scale that leaves no
 *    significant digits took a left-shift that prepended a digit without
 *    checking the array bound.
 *
 * Both are AddressSanitizer heap-buffer-overflow writes reachable from the
 * public NSDecimalAdd / NSDecimalRound functions.  As well as not overflowing,
 * the operations must still produce the correct value, and ordinary
 * (non-maximal) operations must be unaffected.
 */

#import <Foundation/Foundation.h>
#import <Foundation/NSDecimal.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSDecimal max-length mantissa")
  NSDecimal	a, r, e;
  NSString	*nines = @"99999999999999999999999999999999999999";   /* 38 nines */

  /* F-DEC1: carry-out when adding two full mantissas -> 2e38. */
  NSDecimalFromString(&a, nines, nil);
  NSDecimalAdd(&r, &a, &a, NSRoundPlain);
  NSDecimalFromString(&e, @"200000000000000000000000000000000000000", nil);
  PASS(r.validNumber && NSDecimalCompare(&r, &e) == NSOrderedSame,
    "adding two maximum-length mantissas gives 2e38 without overflow");

  /* An ordinary carrying add (not at the mantissa limit) is unaffected. */
  NSDecimalFromString(&a, @"999", nil);
  NSDecimalAdd(&r, &a, &a, NSRoundPlain);
  NSDecimalFromString(&e, @"1998", nil);
  PASS(NSDecimalCompare(&r, &e) == NSOrderedSame,
    "an ordinary carrying add (999 + 999) still gives 1998");

  /* F-DEC2: rounding a full mantissa at a scale that keeps no digits -> 1e38. */
  NSDecimalFromString(&a, nines, nil);
  NSDecimalRound(&r, &a, -38, NSRoundPlain);
  NSDecimalFromString(&e, @"100000000000000000000000000000000000000", nil);
  PASS(r.validNumber && NSDecimalCompare(&r, &e) == NSOrderedSame,
    "rounding a maximum-length mantissa at scale -38 gives 1e38 without overflow");

  /* An ordinary l==0 round (not at the limit) is unaffected. */
  NSDecimalFromString(&a, @"999", nil);
  NSDecimalRound(&r, &a, -3, NSRoundPlain);
  NSDecimalFromString(&e, @"1000", nil);
  PASS(NSDecimalCompare(&r, &e) == NSOrderedSame,
    "an ordinary round up to a new digit (999 at scale -3) still gives 1000");

  END_SET("NSDecimal max-length mantissa")
  return 0;
}
