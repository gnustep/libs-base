/*
 * codertype.m - regression test for -[NSValue initWithCoder:].
 *
 * The decoder reads an objc-type-string length straight from the
 * archive and copies that many bytes into a 64-byte stack buffer
 * (`char type[64]') whenever the length is <= 64.  When the length is
 * exactly 64 the buffer is filled completely, leaving no room for a
 * terminator, yet the bytes are then used as a NUL-terminated C string
 * (strncmp / valueClassWithObjCType:), reading past the end of the
 * buffer.  The decoder now rejects a type string that is not
 * NUL-terminated.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

/* A coder that feeds -initWithCoder: a 64-byte object-type string with
 * no NUL terminator - the input only a crafted archive could produce.
 */
@interface TypeCoder : NSCoder
@end

@implementation TypeCoder
- (void) decodeValueOfObjCType: (const char*)type at: (void*)data
{
  /* The first (and only, before the fix raises) unsigned decoded is the
   * length of the object-type string: claim a full 64 bytes. */
  if (strcmp(type, @encode(unsigned)) == 0)
    {
      *(unsigned*)data = 64;
    }
}
- (void) decodeArrayOfObjCType: (const char*)type
			 count: (NSUInteger)count
			    at: (void*)data
{
  /* Fill the whole type buffer with non-NUL bytes. */
  if (strcmp(type, @encode(signed char)) == 0)
    {
      memset(data, 'A', count);
    }
}
- (NSInteger) versionForClassName: (NSString*)className
{
  return 3;
}
- (NSZone*) objectZone
{
  return NSDefaultMallocZone();
}
@end

int
main(int argc, char *argv[])
{
  START_SET("NSValue initWithCoder type-string termination")
  TypeCoder	*tc;
  NSValue	*original;
  NSData	*archived;
  NSValue	*restored;

  /* Positive control: a real value still round-trips through
   * NSArchiver/NSUnarchiver (a valid type string is NUL-terminated and
   * must not be rejected).
   */
  original = [NSValue valueWithRange: NSMakeRange(3, 7)];
  archived = [NSArchiver archivedDataWithRootObject: original];
  restored = [NSUnarchiver unarchiveObjectWithData: archived];
  PASS_EQUAL(restored, original,
    "a valid NSValue still round-trips through the coder")

  /* Attack: a 64-byte type string with no terminator must be rejected
   * rather than over-read as a C string.
   */
  tc = [TypeCoder new];
  PASS_EXCEPTION(
    [[NSValue alloc] initWithCoder: tc],
    NSInvalidArgumentException,
    "an unterminated 64-byte type string is rejected, not over-read")
  RELEASE(tc);

  END_SET("NSValue initWithCoder type-string termination")

  return 0;
}
