/*
 * string.m - regression test for +[NSDecimalNumber decimalNumberWithString:].
 *
 * NSDecimalFromString() -> GSDecimalFromString() copied the digits of the
 * supplied string into the fixed-size cMantissa[] array of a stack decimal
 * with no bound on the destination index, so a numeric string with more
 * digits than the mantissa can hold overran the buffer - a stack buffer
 * overflow on attacker-controlled text reachable from
 * +decimalNumberWithString: and from property-list / archive decoding.
 * The digit loops now stop filling the mantissa at its capacity (excess
 * integer digits raise the exponent; excess fractional digits are dropped).
 *
 *   - a normal decimal string still parses to the right value.
 *   - a string with far more digits than the mantissa holds is parsed
 *     without overflowing the buffer (and does not crash).
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* "<prefix><n copies of '1'>" */
static NSString *
longDigits(NSString *prefix, unsigned n)
{
  NSMutableString	*s;
  unsigned		i;

  s = [NSMutableString stringWithCapacity: n + [prefix length]];
  [s appendString: prefix];
  for (i = 0; i < n; i++)
    {
      [s appendString: @"1"];
    }
  return s;
}

int
main(int argc, char *argv[])
{
  START_SET("NSDecimalNumber decimalNumberWithString")
  NSDecimalNumber	*d;

  d = [NSDecimalNumber decimalNumberWithString: @"123.45"];
  PASS(d != nil
    && [d doubleValue] > 123.44 && [d doubleValue] < 123.46,
    "a normal decimal string parses to the right value")

  /* 300 fractional digits is far more than the mantissa can hold; it must be
   * parsed (with reduced precision) without overflowing the buffer. */
  d = [NSDecimalNumber decimalNumberWithString: longDigits(@"0.", 300)];
  PASS(d != nil,
    "a 300-fractional-digit string is parsed without overflowing the mantissa")

  /* 300 integer digits likewise must not overflow the buffer. */
  d = [NSDecimalNumber decimalNumberWithString: longDigits(@"", 300)];
  PASS(d != nil,
    "a 300-integer-digit string is parsed without overflowing the mantissa")

  END_SET("NSDecimalNumber decimalNumberWithString")

  return 0;
}
