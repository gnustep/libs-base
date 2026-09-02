/*
 * bplist-bigcontainer-bounds.m - regression test for the binary
 * property list "big" array (0xAF) and dictionary (0xDF) element
 * counts.
 *
 * When GSBinaryPLParser -objectAtIndex: meets a 0xAF or 0xDF marker it
 * reads an element count straight from the data and then both
 *
 *     objects = NSAllocateCollectable(sizeof(id) * count, ...)
 *
 * and a loop that calls -readObjectIndexAt: count (array) or 2*count
 * (dictionary) times.  Neither the allocation nor the loop was bounded
 * against the amount of data actually present, so a crafted marker that
 * declares billions of elements over a handful of bytes makes the loop
 * read object indices far past the end of the buffer (and, on 32-bit,
 * wraps the sizeof(id)*count product to an undersized allocation).  The
 * fix bounds count by the bytes remaining for the index entries:
 *
 *     count > (_length - counter) / index_size           (array)
 *     count > (_length - counter) / (2 * index_size)      (dictionary)
 *
 * which never forms the overflowing product and rejects the implausible
 * count before allocating or reading.
 *
 * These buffers cannot be produced by +dataWithPropertyList:; the test
 * assembles them directly as raw bytes.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Build a bplist whose single (root) object is a "big" container
 * marker (0xAF array or 0xDF dictionary) declaring 'count' elements via
 * a 0x12 four-byte length, over an otherwise empty body.  A one-entry
 * offset table and a 32-byte trailer make the buffer pass the
 * structural checks in -initWithData: so that parsing reaches
 * -objectAtIndex: and the big-container branch.
 */
static NSData *
craftBigContainer(uint8_t marker, uint32_t count)
{
  unsigned char	buf[47];
  unsigned char	*b = buf;
  unsigned char	*tr;

  memset(buf, 0, sizeof(buf));
  memcpy(b, "bplist00", 8);

  /* object 0 at offset 8: marker, 0x12, then a 4-byte big-endian count */
  b[8]  = marker;
  b[9]  = 0x12;
  b[10] = (unsigned char)((count >> 24) & 0xff);
  b[11] = (unsigned char)((count >> 16) & 0xff);
  b[12] = (unsigned char)((count >>  8) & 0xff);
  b[13] = (unsigned char)( count        & 0xff);

  /* one-entry offset table at offset 14: object 0 lives at offset 8 */
  b[14] = 0x08;

  /* 32-byte trailer at offset 15: offset_size, index_size both 1,
   * object_count 1, root_index 0, table_start 14 (low bytes only). */
  tr = b + 15;
  tr[6]  = 1;
  tr[7]  = 1;
  tr[15] = 1;
  tr[23] = 0;
  tr[31] = 14;

  return [NSData dataWithBytes: buf length: sizeof(buf)];
}

int
main(int argc, char *argv[])
{
  START_SET("NSPropertyList binary plist big-container bounds")
  NSMutableArray	*bigArray;
  NSMutableDictionary	*bigDict;
  NSData		*serialized;
  NSData		*crafted;
  unsigned		i;

  /* Positive control: a real array large enough to be encoded with the
   * 0xAF "big array" marker must still round-trip.  Guards against a fix
   * that tightens the bound so far that valid input is rejected.
   */
  bigArray = [NSMutableArray array];
  for (i = 0; i < 20; i++)
    {
      [bigArray addObject: [NSNumber numberWithUnsignedInt: i]];
    }
  serialized = [NSPropertyListSerialization
                 dataWithPropertyList: bigArray
                               format: NSPropertyListBinaryFormat_v1_0
                              options: 0
                                error: NULL];
  PASS(serialized != nil, "20-element array serialized as a big-array bplist")
  PASS_EQUAL([NSPropertyListSerialization
               propertyListWithData: serialized
                            options: NSPropertyListImmutable
                              format: NULL
                                error: NULL],
    bigArray,
    "valid big-array bplist round-trips through the parser")

  /* Positive control: the dictionary equivalent for the 0xDF branch. */
  bigDict = [NSMutableDictionary dictionary];
  for (i = 0; i < 20; i++)
    {
      [bigDict setObject: [NSNumber numberWithUnsignedInt: i]
                  forKey: [NSString stringWithFormat: @"k%u", i]];
    }
  serialized = [NSPropertyListSerialization
                 dataWithPropertyList: bigDict
                               format: NSPropertyListBinaryFormat_v1_0
                              options: 0
                                error: NULL];
  PASS(serialized != nil, "20-entry dictionary serialized as a big-dict bplist")
  PASS_EQUAL([NSPropertyListSerialization
               propertyListWithData: serialized
                            options: NSPropertyListImmutable
                              format: NULL
                                error: NULL],
    bigDict,
    "valid big-dict bplist round-trips through the parser")

  /* Attack 1: a 0xAF big array that declares ~268M elements over a
   * 47-byte buffer.  Without the bound the parser allocates for and
   * walks billions of object indices past the end of the data.
   */
  crafted = craftBigContainer(0xAF, 0x0FFFFFFFu);
  PASS_EQUAL(([NSPropertyListSerialization
                    propertyListWithData: crafted
                                 options: NSPropertyListImmutable
                                  format: NULL
                                   error: NULL]),
    nil,
    "0xAF big array with implausible element count rejected")

  /* Attack 2: the 0xDF big-dictionary equivalent. */
  crafted = craftBigContainer(0xDF, 0x0FFFFFFFu);
  PASS_EQUAL(([NSPropertyListSerialization
                    propertyListWithData: crafted
                                 options: NSPropertyListImmutable
                                  format: NULL
                                   error: NULL]),
    nil,
    "0xDF big dictionary with implausible element count rejected")

  END_SET("NSPropertyList binary plist big-container bounds")
  return 0;
}
