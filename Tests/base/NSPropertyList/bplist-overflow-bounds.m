/*
 * bplist-overflow-bounds.m - regression test for the binary property
 * list offset-table bounds check.
 *
 * A binary plist trailer declares object_count, offset_size, and
 * table_start. The parser needs
 *
 *   object_count * offset_size <= _length - table_start
 *
 * before it is safe to index into the offset table. Before the bound
 * was rewritten, this was written literally as
 *
 *   table_start + object_count * offset_size > _length
 *
 * which overflows on 32-bit unsigned whenever the product of
 * object_count and offset_size exceeds 2^32 - 1. Because offset_size
 * is already bounded to 1..4 by an earlier guard, any
 * attacker-controlled object_count near or above 2^30 can wrap the
 * product past 2^32 and make the sum land below _length, at which
 * point offsetForIndex: indexes arbitrary memory past the end of the
 * supplied data.
 *
 * This test crafts several such trailers directly as raw bytes (the
 * normal dataWithPropertyList: serializer cannot produce them) and
 * confirms the parser rejects them. A positive control ensures a
 * legitimately serialized bplist still round-trips.
 *
 * Harness note: the binary-plist branch of
 * +[NSPropertyListSerialization propertyListWithData:options:format:error:]
 * raises NSException on malformed input rather than populating the
 * error out-parameter (the gnustep-binary branch wraps its parse in
 * NS_DURING, but the bplist00 branch does not). The test therefore
 * wraps each parse call in NS_DURING so that the exception is
 * observable as a rejection. This is the legitimate use of NS_DURING
 * around code-under-test that throws; it is not the wrapper-class +
 * NSAssert pattern, which has no place in a regression test.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Assemble a raw binary-plist buffer with a caller-specified trailer.
 * Byte 8 holds a single 0x09 (the bplist encoding of YES) so there is
 * a nominal object for the root index to point at; bytes 9..len-33 are
 * left as zero fill (the parser will not touch them unless it walks
 * the offset table, which is what the bounds check is meant to
 * prevent). The 32-byte trailer is placed at the end of the buffer.
 *
 * GNUstep's parser reads object_count / root_index / table_start from
 * the lower four bytes of each 8-byte trailer field (postfix[12..15],
 * postfix[20..23], postfix[28..31]), so only 32-bit values need to be
 * threaded through this helper.
 */
static NSData *
craftBplist(uint32_t object_count,
            uint8_t  offset_size,
            uint8_t  index_size,
            uint32_t root_index,
            uint32_t table_start,
            unsigned total_length)
{
  NSMutableData	*d;
  unsigned char	*b;
  unsigned char	postfix[32];

  if (total_length < 33)
    {
      total_length = 33;
    }
  d = [NSMutableData dataWithLength: total_length];
  b = (unsigned char *)[d mutableBytes];

  memcpy(b, "bplist00", 8);
  b[8] = 0x09;  /* a single "true" object so root_index = 0 is nominal */

  memset(postfix, 0, sizeof(postfix));
  postfix[6]  = offset_size;
  postfix[7]  = index_size;
  postfix[12] = (unsigned char)((object_count >> 24) & 0xff);
  postfix[13] = (unsigned char)((object_count >> 16) & 0xff);
  postfix[14] = (unsigned char)((object_count >>  8) & 0xff);
  postfix[15] = (unsigned char)( object_count        & 0xff);
  postfix[20] = (unsigned char)((root_index >> 24) & 0xff);
  postfix[21] = (unsigned char)((root_index >> 16) & 0xff);
  postfix[22] = (unsigned char)((root_index >>  8) & 0xff);
  postfix[23] = (unsigned char)( root_index        & 0xff);
  postfix[28] = (unsigned char)((table_start >> 24) & 0xff);
  postfix[29] = (unsigned char)((table_start >> 16) & 0xff);
  postfix[30] = (unsigned char)((table_start >>  8) & 0xff);
  postfix[31] = (unsigned char)( table_start        & 0xff);

  memcpy(b + total_length - 32, postfix, 32);
  return d;
}

/* Invoke the binary-plist parser and report whether the call was
 * rejected. The parser raises on malformed input, so a thrown
 * exception counts as a rejection; so does a nil return. Anything
 * else means the parser accepted the buffer, which is what this
 * test is trying to rule out for overflow-bait trailers.
 */
static BOOL
bplistRejected(NSData *data)
{
  id	result = nil;
  BOOL	threw = NO;

  NS_DURING
    {
      NSError		*error = nil;
      NSPropertyListFormat fmt = 0;

      result = [NSPropertyListSerialization
		 propertyListWithData: data
			      options: NSPropertyListImmutable
			       format: &fmt
				error: &error];
    }
  NS_HANDLER
    {
      threw = YES;
    }
  NS_ENDHANDLER
  return (threw || result == nil);
}

/* Invoke the parser and return the result object (or nil if the
 * parser rejected the buffer by exception or by returning nil).
 * Used by the positive-control assertion.
 */
static id
bplistParse(NSData *data)
{
  id	result = nil;

  NS_DURING
    {
      NSError		*error = nil;
      NSPropertyListFormat fmt = 0;

      result = [NSPropertyListSerialization
		 propertyListWithData: data
			      options: NSPropertyListImmutable
			       format: &fmt
				error: &error];
    }
  NS_HANDLER
    {
      result = nil;
    }
  NS_ENDHANDLER
  return result;
}

int
main(int argc, char *argv[])
{
  START_SET("NSPropertyList binary plist offset-table bounds")
  NSDictionary	*valid;
  NSData	*serialized;
  NSData	*crafted;
  id		parsed;

  /* Positive control: a legitimately serialized bplist must still
   * parse, round-trip, and compare equal. This catches any fix that
   * regresses the happy path by tightening the check too far.
   */
  valid = [NSDictionary dictionaryWithObjectsAndKeys:
    @"value", @"key", nil];
  serialized = [NSPropertyListSerialization
		 dataWithPropertyList: valid
			       format: NSPropertyListBinaryFormat_v1_0
			      options: 0
				error: NULL];
  PASS(serialized != nil, "valid dictionary serialized as bplist")
  parsed = bplistParse(serialized);
  PASS([parsed isEqual: valid],
    "valid bplist round-trips through the parser")

  /* Attack 1: object_count = 0x40000000, offset_size = 4. On 32-bit
   * unsigned the product wraps to zero, which would defeat the
   * pre-fix naive sum check. The buffer is intentionally short so
   * that even a one-entry table walk is OOB.
   */
  crafted = craftBplist(0x40000000u, 4, 1,
                        /*root_index*/ 0,
                        /*table_start*/ 9,
                        /*total_length*/ 64);
  PASS(bplistRejected(crafted),
    "object_count=0x40000000 offset_size=4 (product wraps to 0) rejected")

  /* Attack 2: the maximum 32-bit object_count with the same
   * offset_size. The product wraps to a small value (4 * 2^32 - 4),
   * again defeating a naive sum check.
   */
  crafted = craftBplist(0xffffffffu, 4, 1,
                        /*root_index*/ 0,
                        /*table_start*/ 9,
                        /*total_length*/ 64);
  PASS(bplistRejected(crafted),
    "object_count=0xffffffff offset_size=4 rejected")

  END_SET("NSPropertyList binary plist offset-table bounds")

  return 0;
}
