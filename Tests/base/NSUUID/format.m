/*
 * format.m - tests for NSUUID string/byte layout that basic.m does not cover:
 * that a UUID string parses to the expected bytes in order (and back), that
 * parsing accepts lower case and produces upper case, rejects malformed
 * strings, and that +UUID yields distinct, well-formed values.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSUUID string and byte layout")
    NSString		*str = @"E621E1F8-C36C-495A-93FC-0C247A3E6E5F";
    unsigned char	expected[16] = {
      0xE6, 0x21, 0xE1, 0xF8, 0xC3, 0x6C, 0x49, 0x5A,
      0x93, 0xFC, 0x0C, 0x24, 0x7A, 0x3E, 0x6E, 0x5F };
    unsigned char	bytes[16];
    NSUUID		*u;
    int			i;
    BOOL		ok = YES;

    u = [[[NSUUID alloc] initWithUUIDString: str] autorelease];
    [u getUUIDBytes: bytes];
    for (i = 0; i < 16; i++)
      if (bytes[i] != expected[i])
	ok = NO;
    PASS(ok, "initWithUUIDString maps the hex pairs to bytes in order");

    u = [[[NSUUID alloc] initWithUUIDBytes: expected] autorelease];
    PASS_EQUAL([u UUIDString], str,
      "initWithUUIDBytes formats the bytes back to the same string");
  END_SET("NSUUID string and byte layout")

  START_SET("NSUUID string parsing")
    NSString	*upper = @"E621E1F8-C36C-495A-93FC-0C247A3E6E5F";
    NSUUID	*u;

    u = [[[NSUUID alloc] initWithUUIDString:
      @"e621e1f8-c36c-495a-93fc-0c247a3e6e5f"] autorelease];
    PASS_EQUAL([u UUIDString], upper,
      "initWithUUIDString accepts lower case and formats upper case");

    PASS([[NSUUID alloc] initWithUUIDString: @""] == nil,
      "an empty string is rejected");
    PASS([[NSUUID alloc] initWithUUIDString:
      @"E621E1F8-C36C-495A-93FC-0C247A3E6E5"] == nil,
      "a too-short string is rejected");
    PASS([[NSUUID alloc] initWithUUIDString:
      @"E621E1F8-C36C-495A-93FC-0C247A3E6E5G"] == nil,
      "a string with a non-hex digit is rejected");
  END_SET("NSUUID string parsing")

  START_SET("NSUUID generation and format")
    NSUUID	*a = [NSUUID UUID];
    NSUUID	*b = [NSUUID UUID];
    NSString	*s = [a UUIDString];

    PASS(![a isEqual: b], "two generated UUIDs are distinct");
    PASS([s length] == 36, "a UUID string is 36 characters long");
    PASS([s characterAtIndex: 8] == '-' && [s characterAtIndex: 13] == '-'
      && [s characterAtIndex: 18] == '-' && [s characterAtIndex: 23] == '-',
      "the UUID string is hyphenated as 8-4-4-4-12");
  END_SET("NSUUID generation and format")

  return 0;
}
