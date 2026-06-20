/*
 * deserializeints.m - regression test for -[NSData deserializeInts:count:...].
 *
 * -deserializeInts:count:atCursor: and -deserializeInts:count:atIndex: passed
 * &intBuffer (the address of the local pointer parameter) to
 * -deserializeBytes:length:atCursor: instead of intBuffer, so the decoded
 * bytes were written over the pointer variable on the stack rather than into
 * the caller's buffer - smashing the stack and leaving the caller's buffer
 * untouched.  The bytes are now written into the caller's buffer.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int
main(int argc, char *argv[])
{
  START_SET("NSData deserializeInts")
  /* three 32-bit ints in big-endian (network) byte order */
  unsigned char	bytes[12] = {
    0x01, 0x02, 0x03, 0x04,
    0x05, 0x06, 0x07, 0x08,
    0x09, 0x0a, 0x0b, 0x0c };
  NSData	*d = [NSData dataWithBytes: bytes length: 12];
  int		out[3];
  unsigned	cursor = 0;

  out[0] = out[1] = out[2] = 0;
  [d deserializeInts: out count: 3 atCursor: &cursor];
  PASS(out[0] == 0x01020304 && out[1] == 0x05060708 && out[2] == 0x090a0b0c,
    "deserializeInts:count:atCursor: writes into the caller's buffer")

  out[0] = out[1] = out[2] = 0;
  [d deserializeInts: out count: 3 atIndex: 0];
  PASS(out[0] == 0x01020304 && out[1] == 0x05060708 && out[2] == 0x090a0b0c,
    "deserializeInts:count:atIndex: writes into the caller's buffer")

  END_SET("NSData deserializeInts")

  return 0;
}
