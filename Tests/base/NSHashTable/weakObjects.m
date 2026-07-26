#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHashTable.h>

int main()
{
  START_SET("NSHashTable weak objects")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSHashTable 		*hashTable = [NSHashTable weakObjectsHashTable];
  NSAutoreleasePool 	*arp2 = [NSAutoreleasePool new];
  unsigned		counter;

  id testObj = [[[NSObject alloc] init] autorelease];
  [hashTable addObject: testObj];
  counter = 0;
  for (id o in hashTable)
    {
      counter++;
    }
  PASS(counter == 1,
    "Table fast enumeration sees active weak reference")
  PASS([[hashTable allObjects] count] == 1,
    "Table retains active weak reference")

  [arp2 release]; arp2 = nil;

  counter = 0;
  for (id o in hashTable)
    {
      counter++;
    }
  PASS(counter == 0,
    "Table fast enumeration does not see deallocated weak reference")
  PASS([[hashTable allObjects] count] == 0,
    "Table removes dead weak reference")

  [arp release]; arp = nil;
  END_SET("NSHashTable weak objects")
  return 0;
}
