/*
 * cstring.m - regression test for +[NSDeserializer deserializePropertyList...].
 *
 * The ST_CSTRING case of the deserializer read a byte count from the
 * (untrusted) data and built the string with `length: size - 1'.  A crafted
 * length of 0 made `size - 1' underflow to a huge value, so the string was
 * created over a zero-byte buffer claiming ~4 billion bytes - an out-of-bounds
 * read.  A zero C-string length is now rejected.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

int
main(int argc, char *argv[])
{
  START_SET("NSDeserializer C-string length")
  NSMutableData	*d = [NSMutableData data];
  /* byte 0: no uniquing (old format); byte 1: ST_CSTRING tag (1) */
  unsigned char	hdr[2] = { 0x00, 0x01 };
  id		result = @"unset";

  [d appendBytes: hdr length: 2];
  [d serializeInt: 0];	/* C-string byte count; a valid one is always >= 1 */

  PASS_EXCEPTION(
    (result = [NSDeserializer deserializePropertyListFromData: d
                                            mutableContainers: NO]),
    NSInvalidArgumentException,
    "a zero C-string length in serialized data is rejected, not used as size - 1")

  END_SET("NSDeserializer C-string length")

  return 0;
}
