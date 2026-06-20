/*
 * arrayoverflow.m - regression test for _NSKeyedCoderOldStyleArray decoding.
 *
 * -[NSKeyedArchiver encodeArrayOfObjCType:count:at:] stores a C array as an
 * _NSKeyedCoderOldStyleArray.  Its -initWithCoder: allocated the destination
 * buffer with -[NSMutableData initWithLength: _c * _s], where _c (the decoded
 * NS.count) and _s (the element size) are both `unsigned`.  The 32-bit
 * product truncated before being widened, so an attacker-chosen NS.count made
 * the buffer far smaller than the _c elements the following loop wrote into it
 * - a heap buffer overflow when unarchiving an untrusted archive.  The count
 * is now validated against the size before allocating.
 *
 *   - a normal C array still round-trips through the keyed archiver.
 *   - an archive whose NS.count * element-size overflows is rejected rather
 *     than allocating an undersized buffer and overrunning it.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

@interface ArrayHolder : NSObject <NSCoding>
@end

@implementation ArrayHolder
- (void) encodeWithCoder: (NSCoder*)c
{
  double	a[3];

  a[0] = 1.0; a[1] = 2.0; a[2] = 3.0;
  [c encodeArrayOfObjCType: @encode(double) count: 3 at: a];
}
- (id) initWithCoder: (NSCoder*)c
{
  double	a[3];

  [c decodeArrayOfObjCType: @encode(double) count: 3 at: a];
  return self;
}
@end

/* Build a keyed archive of an ArrayHolder, then rewrite the NS.count of the
 * encoded C array to a value whose product with the 8-byte element size
 * overflows 32 bits (0x20000000 * 8 == 0x100000000 -> 0).
 */
static NSData *
tamperedArchive(void)
{
  NSData		*archive;
  NSMutableDictionary	*plist;
  NSMutableArray	*objects;
  NSUInteger		i;

  archive = [NSKeyedArchiver archivedDataWithRootObject:
    [[[ArrayHolder alloc] init] autorelease]];
  plist = [NSPropertyListSerialization
    propertyListWithData: archive
		 options: NSPropertyListMutableContainersAndLeaves
		  format: NULL
		   error: NULL];
  objects = [plist objectForKey: @"$objects"];
  for (i = 0; i < [objects count]; i++)
    {
      id	o = [objects objectAtIndex: i];

      if ([o isKindOfClass: [NSDictionary class]]
	&& [o objectForKey: @"NS.count"] != nil)
	{
	  [o setObject: [NSNumber numberWithUnsignedInt: 0x20000000U]
		forKey: @"NS.count"];
	}
    }
  return [NSPropertyListSerialization
    dataWithPropertyList: plist
		  format: NSPropertyListBinaryFormat_v1_0
		 options: 0
		   error: NULL];
}

int
main(int argc, char *argv[])
{
  START_SET("_NSKeyedCoderOldStyleArray count overflow")
  NSData	*good;
  id		obj;

  good = [NSKeyedArchiver archivedDataWithRootObject:
    [[[ArrayHolder alloc] init] autorelease]];
  obj = [NSKeyedUnarchiver unarchiveObjectWithData: good];
  PASS(obj != nil, "a normal C-array archive unarchives")

  PASS_EXCEPTION([NSKeyedUnarchiver unarchiveObjectWithData: tamperedArchive()],
    NSInvalidArgumentException,
    "an overflowing array count in an archive is rejected, not overrun")

  END_SET("_NSKeyedCoderOldStyleArray count overflow")

  return 0;
}
