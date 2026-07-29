/*
 * number.m - regression test for NSJSONSerialization numeric-token length.
 *
 * parseNumber() accumulates the characters of a JSON numeric token into a
 * fixed 255-byte stack buffer via the BUFFER() macro. The macro's overflow
 * guard raised a parse error when the buffer was full but did not stop, so
 * control fell through to the store and a numeric token longer than the
 * buffer kept writing past the end of the stack array - an unbounded stack
 * buffer overflow on attacker-controlled input. The guard now rejects the
 * token (returns with the error set) instead of overrunning the buffer.
 *
 *   - a normal number still parses.
 *   - a numeric token far longer than the internal buffer is rejected with
 *     an error rather than overflowing the buffer (and does not crash).
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Build "[<digits copies of '1'>]" so the numeric token is `digits`
 * characters long.
 */
static NSData *
buildLongNumberJSON(unsigned digits)
{
  NSMutableString	*s;
  unsigned		i;

  s = [NSMutableString stringWithCapacity: digits + 2];
  [s appendString: @"["];
  for (i = 0; i < digits; i++)
    {
      [s appendString: @"1"];
    }
  [s appendString: @"]"];
  return [s dataUsingEncoding: NSUTF8StringEncoding];
}

#define	ISARRAY(X) [X isKindOfClass: [NSArray class]]
#define	ISERROR(X) [X isKindOfClass: [NSError class]]

int
main(int argc, char *argv[])
{
  START_SET("NSJSONSerialization number length")
  NSData	*data;
  NSError	*error;
  NSError	*dummy = [[[NSError alloc] init] autorelease];
  id		result;

  data = [@"[123]" dataUsingEncoding: NSUTF8StringEncoding];
  error = dummy;
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(ISARRAY(result) && [[result objectAtIndex: 0] intValue] == 123,
    "a normal JSON number parses")
  PASS(error == nil, "a normal JSON number cleared the error out-parameter")

  /* A 4096-character numeric token is far longer than the 255-byte buffer:
   * it must be rejected via the error out-parameter rather than overflowing
   * the stack buffer.
   */
  data = buildLongNumberJSON(4096);
  error = dummy;
  result = [NSJSONSerialization JSONObjectWithData: data
					   options: 0
					     error: &error];
  PASS(result == nil, "an over-long JSON numeric token was rejected")
  PASS(ISERROR(error),
    "an over-long JSON numeric token populated the error out-parameter")

  END_SET("NSJSONSerialization number length")

  return 0;
}
