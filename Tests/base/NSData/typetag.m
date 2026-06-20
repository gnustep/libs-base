/*
 * typetag.m - regression test for -[NSData deserializeTypeTag:andCrossRef:...].
 *
 * The NSDataStatic override of -deserializeTypeTag:andCrossRef:atCursor:
 * guarded its 4-byte cross-reference read with `*cursor >= length-3'.  As
 * `length' is unsigned, a buffer shorter than 3 bytes made `length-3'
 * underflow to a huge value, defeating the guard and reading up to 4 bytes
 * past the end of the buffer.  The subtraction is now guarded against
 * underflow.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

int
main(int argc, char *argv[])
{
  START_SET("NSData deserializeTypeTag short buffer")
  /* Tag byte 0x70 == _GSC_MAYX | _GSC_X_4: a 32-bit cross-reference follows.
   * In a 2-byte no-copy (static) buffer, decoding that cross-reference would
   * read 4 bytes starting one past the tag - off the end of the buffer.
   */
  unsigned char	bytes[2] = { 0x70, 0x00 };
  NSData	*d = [NSData dataWithBytesNoCopy: bytes length: 2 freeWhenDone: NO];
  unsigned char	tag = 0;
  unsigned int	ref = 0;
  unsigned int	cursor = 0;

  PASS_EXCEPTION(
    [d deserializeTypeTag: &tag andCrossRef: &ref atCursor: &cursor],
    NSRangeException,
    "a cross-ref tag in too short a buffer raises rather than reading out of bounds")

  END_SET("NSData deserializeTypeTag short buffer")

  return 0;
}
