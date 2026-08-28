/*
 * bplist-string-bounds.m - regression test for the binary property list parser.
 *
 * In -[GSBinaryPLParser objectAtIndex:] the string object cases (short/long
 * UTF-8 and UTF-16, markers 0x50-0x5F and 0x60-0x6F) read `len' bytes from the
 * object body with no check that the body stays within the data - unlike the
 * sibling data cases (0x40-0x4F).  A crafted string object claiming a length
 * past the end of the data therefore read out of bounds.  The string cases now
 * validate the length against the remaining data.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

int
main(int argc, char *argv[])
{
  START_SET("binary plist string length bounds")
  /* A minimal bplist00 whose single (root) object is a long UTF-8 string
   * (marker 0x5F) declaring a 0x00FFFFFF (16 MB) length, with no string body.
   * Layout:
   *   [0..7]   "bplist00"
   *   [8]      0x5F            long UTF-8 string
   *   [9]      0x12            4-byte count follows
   *   [10..13] 00 FF FF FF     length = 0x00FFFFFF
   *   [14]     0x08            offset table: object 0 is at offset 8
   *   [15..46] 32-byte trailer (offset_size=1, index_size=1,
   *            object_count=1, root_index=0, table_start=14)
   */
  unsigned char	buf[47];
  NSData	*d;
  NSError	*err = (NSError*)@"sentinel";
  id		result = @"sentinel";

  memset(buf, 0, sizeof(buf));
  memcpy(buf, "bplist00", 8);
  buf[8]  = 0x5F;
  buf[9]  = 0x12;
  buf[10] = 0x00; buf[11] = 0xFF; buf[12] = 0xFF; buf[13] = 0xFF;
  buf[14] = 0x08;
  buf[15 + 6]  = 0x01;	/* offset_size */
  buf[15 + 7]  = 0x01;	/* index_size  */
  buf[15 + 15] = 0x01;	/* object_count = 1 */
  buf[15 + 31] = 14;	/* table_start = 14 */

  d = [NSData dataWithBytes: buf length: sizeof(buf)];
  result = [NSPropertyListSerialization propertyListWithData: d
                                                    options: 0
                                                     format: NULL
                                                      error: &err];
  PASS(result == nil,
    "a binary plist string claiming a length past the data is rejected")
  PASS(err != nil && [err isKindOfClass: [NSError class]],
    "the over-long binary plist string sets the error out-parameter")

  END_SET("binary plist string length bounds")

  return 0;
}
