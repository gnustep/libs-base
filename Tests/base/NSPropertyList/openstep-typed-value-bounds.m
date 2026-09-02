/*
 * openstep-typed-value-bounds.m - regression test for the OpenStep
 * (old-style ASCII) property list parser's GNUstep-extended typed
 * values <*Type...>.
 *
 * When parsePlItem() meets a <*I...>, <*D...> or <*R...> token it
 * measures the token body as
 *
 *     len = (distance to the closing '>')
 *
 * straight from the input and then parses it through a stack buffer
 * sized from that length:
 *
 *     char    buf[len+1];   // <*I... integer
 *     unichar buf[len];     // <*D... date   (2*len bytes)
 *     char    buf[len+1];   // <*R... real
 *
 * These are C99 variable-length arrays on the stack, bounded only by
 * the size of the input.  A token such as <*I000...0> with a few
 * hundred KB of digits therefore allocates a same-sized array on the
 * stack and the copy loop walks past the stack guard page -> SIGSEGV.
 * The token is fully attacker-controlled and reachable from the public
 * +propertyListWithData:options:format:error: (any data that is not
 * binary or XML is parsed as NSPropertyListOpenStepFormat).
 *
 * A legitimate typed value is a short number (NSNumber -stringValue) or
 * a fixed-format date, so the fix rejects an implausibly long token
 * before allocating the buffer rather than overflowing the stack.
 *
 * The over-long tokens here do not crash on the test framework's main
 * thread (its stack is large enough for an 8 KB array); the bug was
 * demonstrated with AddressSanitizer (stack-overflow at the copy loop)
 * and on a small-stacked secondary thread.  This test pins the
 * observable contract of the fix: a valid typed value still parses, and
 * an over-long one is rejected (returns nil) instead of being parsed.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static id
parsePlist(NSData *d)
{
  return [NSPropertyListSerialization propertyListWithData: d
						   options: NSPropertyListImmutable
						    format: NULL
						     error: NULL];
}

static NSData *
asciiPlist(const char *s)
{
  return [NSData dataWithBytes: s length: strlen(s)];
}

/* <*<type><body>> with 'count' repetitions of 'fill' as the body. */
static NSData *
longTypedValue(char type, char fill, unsigned count)
{
  NSMutableData	*m = [NSMutableData dataWithCapacity: count + 8];
  char		head[4];
  char		*body;

  head[0] = '<'; head[1] = '*'; head[2] = type;
  [m appendBytes: head length: 3];
  body = malloc(count);
  memset(body, fill, count);
  [m appendBytes: body length: count];
  free(body);
  [m appendBytes: ">" length: 1];
  return m;
}

int
main(int argc, char *argv[])
{
  START_SET("NSPropertyList OpenStep typed-value bounds")
  id	result;

  /* Positive control: a normal extended integer still parses. */
  result = parsePlist(asciiPlist("<*I12345>"));
  PASS(result != nil
    && [result isKindOfClass: [NSNumber class]]
    && [result longLongValue] == 12345LL,
    "<*I12345> parses to the integer 12345")

  /* Positive control: a normal extended real still parses. */
  result = parsePlist(asciiPlist("<*R2.5>"));
  PASS(result != nil
    && [result isKindOfClass: [NSNumber class]]
    && [result doubleValue] == 2.5,
    "<*R2.5> parses to the real 2.5")

  /* Positive control: a normal extended date still parses. */
  result = parsePlist(asciiPlist("<*D2001-02-03 04:05:06 +0000>"));
  PASS(result != nil, "<*D2001-02-03 04:05:06 +0000> parses to a date")

  /* Attack 1: an extended integer whose token is far longer than any
   * real value.  Without the bound the parser sizes a stack VLA from
   * the token length and overflows the stack; with it the over-long
   * token is rejected.
   */
  PASS_EQUAL(parsePlist(longTypedValue('I', '0', 8192)), nil,
    "over-long <*I...> token rejected instead of overflowing the stack")

  /* Attack 2: the <*R...> real equivalent (same VLA). */
  PASS_EQUAL(parsePlist(longTypedValue('R', '9', 8192)), nil,
    "over-long <*R...> token rejected instead of overflowing the stack")

  END_SET("NSPropertyList OpenStep typed-value bounds")
  return 0;
}
