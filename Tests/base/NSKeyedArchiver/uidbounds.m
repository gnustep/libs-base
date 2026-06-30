/*
 * uidbounds.m - regression test for -[NSKeyedUnarchiver _decodeObject:].
 *
 * The object-reference index decoded from a CF$UID in a keyed archive was used
 * to index the _objMap GSIArray (which is not bounds checked in release builds)
 * before the bounds-checked -[_objects objectAtIndex:].  An archive whose root
 * CF$UID is out of range therefore read past the end of the map - a heap buffer
 * overflow when unarchiving an untrusted archive with assertions compiled out.
 * The index is now range checked, so an out-of-range reference is rejected
 * rather than used to over-read the map.
 *
 *   - a normal object still round-trips through the keyed archiver.
 *   - an archive whose root CF$UID is past the object table is rejected.
 */

#import <Foundation/Foundation.h>
#import "Testing.h"

/* Build a keyed archive, then point its root CF$UID one past the object
 * table (the CF$UID dictionaries the binary plist parser produces are
 * immutable, so replace the whole reference rather than editing it in place).
 */
static NSData *
tamperedArchive(void)
{
  NSData		*archive;
  NSMutableDictionary	*plist;
  NSMutableDictionary	*top;
  NSArray		*objects;
  NSDictionary		*badRef;

  archive = [NSKeyedArchiver archivedDataWithRootObject: @"hello world"];
  plist = [NSPropertyListSerialization
    propertyListWithData: archive
		 options: NSPropertyListMutableContainersAndLeaves
		  format: NULL
		   error: NULL];
  objects = [plist objectForKey: @"$objects"];
  top = [[[plist objectForKey: @"$top"] mutableCopy] autorelease];
  badRef = [NSDictionary dictionaryWithObject:
    [NSNumber numberWithUnsignedInteger: [objects count] + 1]
    forKey: @"CF$UID"];
  [top setObject: badRef forKey: @"root"];
  [plist setObject: top forKey: @"$top"];
  return [NSPropertyListSerialization
    dataWithPropertyList: plist
		  format: NSPropertyListBinaryFormat_v1_0
		 options: 0
		   error: NULL];
}

int
main(int argc, char *argv[])
{
  START_SET("NSKeyedUnarchiver CF$UID bounds")
  ENTER_POOL
  id	obj;

  obj = [NSKeyedUnarchiver unarchiveObjectWithData:
    [NSKeyedArchiver archivedDataWithRootObject: @"hello world"]];
  PASS_EQUAL(obj, @"hello world", "a normal keyed archive unarchives")

  PASS_EXCEPTION([NSKeyedUnarchiver unarchiveObjectWithData: tamperedArchive()],
    NSRangeException,
    "an out-of-range CF$UID in an archive is rejected, not used to over-read")

  LEAVE_POOL
  END_SET("NSKeyedUnarchiver CF$UID bounds")

  return 0;
}
