/*
 * bplist-overflow-bounds.m - regression test for the binary property
 * list offset-table bounds check.
 *
 * GSBinaryPLParser must confirm that the offset table does not run
 * past the end of the supplied data before it calls -offsetForIndex:.
 * The obvious bound,
 *
 *     table_start + object_count * offset_size > _length
 *
 * wraps on 32-bit unsigned for any attacker-controlled object_count
 * whose product with offset_size crosses 2^32.  Because offset_size
 * is already bounded to 1..4 by an earlier guard, object_counts near
 * or above 2^30 are enough to wrap the sum back below _length, so a
 * crafted trailer that declares billions of entries over a handful
 * of bytes slips through the check and -offsetForIndex: then reads
 * past the end of the buffer.  The rewritten bound divides the
 * non-negative difference (_length - table_start) by offset_size and
 * so never forms the overflowing product.
 *
 * These trailers cannot be produced by +dataWithPropertyList:; the
 * test assembles them directly as raw bytes.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Build a raw binary-plist buffer with a caller-specified trailer.
 * Byte 8 holds a single bplist-encoded YES so that the root index
 * points at a nominal object; the rest of the body is zero fill.
 * GSBinaryPLParser reads object_count / root_index / table_start
 * from the lower four bytes of each 8-byte trailer field, so the
 * helper only threads 32-bit values through.
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
  b[8] = 0x09;

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

int
main(int argc, char *argv[])
{
  START_SET("NSPropertyList binary plist offset-table bounds")
  NSDictionary	*valid;
  NSData	*serialized;
  NSData	*crafted;

  /* Positive control: a legitimately serialized bplist must still
   * round-trip.  Guards against a fix that tightens the check too
   * far and starts rejecting valid input.
   */
  valid = [NSDictionary dictionaryWithObjectsAndKeys:
    @"value", @"key", nil];
  serialized = [NSPropertyListSerialization
                 dataWithPropertyList: valid
                               format: NSPropertyListBinaryFormat_v1_0
                              options: 0
                                error: NULL];
  PASS(serialized != nil, "valid dictionary serialized as bplist")
  PASS_EQUAL([NSPropertyListSerialization
               propertyListWithData: serialized
                            options: NSPropertyListImmutable
                             format: NULL
                               error: NULL],
    valid,
    "valid bplist round-trips through the parser")

  /* Attack 1: object_count = 0x40000000, offset_size = 4.  On 32-bit
   * unsigned the product wraps to zero, which would defeat the
   * pre-fix naive sum check.  The buffer is intentionally short so
   * that even a one-entry table walk is out of bounds.
   */
  crafted = craftBplist(0x40000000u, 4, 1,
                        /*root_index*/    0,
                        /*table_start*/   9,
                        /*total_length*/ 64);
  PASS_EQUAL(([NSPropertyListSerialization
                    propertyListWithData: crafted
                                 options: NSPropertyListImmutable
                                  format: NULL
                                   error: NULL]),
    nil,
    "object_count=0x40000000 offset_size=4 (product wraps to 0) rejected")

  /* Attack 2: the maximum 32-bit object_count with the same
   * offset_size.  The product wraps to 4 * 2^32 - 4, a small value
   * that again defeats the naive sum check.
   */
  crafted = craftBplist(0xffffffffu, 4, 1,
                        /*root_index*/    0,
                        /*table_start*/   9,
                        /*total_length*/ 64);
  PASS_EQUAL(([NSPropertyListSerialization
                    propertyListWithData: crafted
                                 options: NSPropertyListImmutable
                                  format: NULL
                                   error: NULL]),
    nil,
    "object_count=0xffffffff offset_size=4 rejected")

  END_SET("NSPropertyList binary plist offset-table bounds")
  return 0;
}
