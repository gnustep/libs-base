#import "ObjectTesting.h"
#import <Foundation/Foundation.h>


static void
testValue(uint64_t value)
{
  NSUUID *u = [[NSUUID alloc] initPacked: value];

  PASS([u packedValue] == value,
    "Round-trip for 0x%016llx",
    (unsigned long long)value);

  /* Ensure the UUID string can be parsed again. */
  NSString *s = [u UUIDString];
  NSUUID *v = [[NSUUID alloc] initWithUUIDString: s];

  PASS(v != nil,
    "UUID string parses for 0x%016llx",
    (unsigned long long)value);

  PASS([v packedValue] == value,
    "Round-trip through UUID string for 0x%016llx",
    (unsigned long long)value);

  RELEASE(v);
  RELEASE(u);
}

int
main(void)
{
  START_SET("NSUUID packed values")

  testValue(0ULL);
  testValue(1ULL);
  testValue(0xfULL);
  testValue(0x10ULL);
  testValue(0xffULL);
  testValue(0x100ULL);

  testValue(0xffffffffULL);
  testValue(0x100000000ULL);

  testValue(0x0123456789abcdefULL);
  testValue(0xfedcba9876543210ULL);

  testValue(0x5555555555555555ULL);
  testValue(0xaaaaaaaaaaaaaaaaULL);

  testValue(UINT64_MAX);

  END_SET("NSUUID packed values")


  START_SET("NSUUID packed uniqueness")

  NSUUID *a = AUTORELEASE([[NSUUID alloc] initPacked: 1234]);
  NSUUID *b = AUTORELEASE([[NSUUID alloc] initPacked: 1235]);

  PASS(![a isEqual: b],
    "Different packed values produce different UUIDs");

  END_SET("NSUUID packed uniqueness")


  START_SET("NSUUID version/variant")

  NSUUID *u = AUTORELEASE([[NSUUID alloc] initPacked: 0x123456789abcdef0ULL]);
  uuid_t bytes;

  [u getUUIDBytes: bytes];

  PASS((bytes[6] & 0xf0) == 0x40,
    "Version nibble is 4");

  PASS((bytes[8] & 0xc0) == 0x80,
    "Variant bits are RFC4122");

  END_SET("NSUUID version/variant")


  START_SET("NSUUID packed ignores randomness")
  unsigned	i;

  NSUUID *u = AUTORELEASE([[NSUUID alloc] initPacked: 0x123456789abcdef0ULL]);
  uuid_t bytes;

  [u getUUIDBytes: bytes];

  /* Flip every random bit while leaving version, variant and packed bits. */

  bytes[8] ^= 0x30;      /* the two random bits in byte 8 */

  for (i = 9; i < 16; i++)
    {
      bytes[i] ^= 0xff;
    }

  NSUUID *v = AUTORELEASE([[NSUUID alloc] initWithUUIDBytes: bytes]);

  PASS([v packedValue] == 0x123456789abcdef0ULL,
    "packedValue ignores random bits");

  END_SET("NSUUID packed ignores randomness")
  return 0;
}
