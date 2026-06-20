/*
 * coderindex.m - regression test for -[NSCharacterSet initWithCoder:].
 *
 * The abstract NSCharacterSet -initWithCoder: decoded an int from the archive
 * and used it directly as an index into the fixed-size cache_set[] array of
 * standard character sets, with no bounds check, so a crafted archive could
 * read (and -retain) an arbitrary out-of-bounds slot.  The index is now range
 * checked.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

/* Minimal coder that feeds one attacker-chosen int to -initWithCoder:. */
@interface BadIndexCoder : NSCoder
{
@public
  int	value;
}
@end

@implementation BadIndexCoder
- (void) decodeValueOfObjCType: (const char*)type at: (void*)data
{
  *(int*)data = value;
}
@end

int
main(int argc, char *argv[])
{
  START_SET("NSCharacterSet initWithCoder index bounds")
  BadIndexCoder	*c = [BadIndexCoder new];

  c->value = 99999;	/* far past the 21 standard character sets */
  PASS_EXCEPTION(
    [[NSCharacterSet alloc] initWithCoder: c],
    NSInvalidArgumentException,
    "an out-of-range standard character set index in an archive is rejected")

  RELEASE(c);
  END_SET("NSCharacterSet initWithCoder index bounds")

  return 0;
}
