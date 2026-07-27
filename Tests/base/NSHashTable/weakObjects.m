#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHashTable.h>

/* Use a subclass of NSObject to ensure that each instance is a separate
 * object (NSObject might return a singleton).
 */
@interface TestClass : NSObject
@end
@implementation	TestClass
- (void) dealloc
{
  DEALLOC
}
- (id) init
{
  self = [super init];
  return self;
}
@end

int main()
{
  START_SET("NSHashTable weak objects")
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSHashTable 		*hashTable = [NSHashTable weakObjectsHashTable];
  NSAutoreleasePool 	*arp2 = [NSAutoreleasePool new];
  NSEnumerator		*e;
  id			o;
  unsigned		counter;

  id testObj = [TestClass new];
[testObj trackOwnership];
  [hashTable addObject: AUTORELEASE([TestClass new])];
  [hashTable addObject: testObj];
  [hashTable addObject: AUTORELEASE([TestClass new])];

  ENTER_POOL
  counter = 0;
  e = [hashTable objectEnumerator];
  while (nil != (o = [e nextObject]))
    {
      counter++;
    }
  PASS(counter == 3,
    "Table standard enumeration sees active weak references")
  counter = 0;
  for (o in hashTable)
    {
      counter++;
    }
  PASS(counter == 3,
    "Table fast enumeration sees active weak references")
  PASS([[hashTable allObjects] count] == 3,
    "Table count has active weak reference")
  LEAVE_POOL

  RELEASE(testObj);
  counter = 0;
  e = [hashTable objectEnumerator];
  while (nil != (o = [e nextObject]))
    {
      counter++;
    }
  PASS(counter == 2,
    "Table standard enumeration sees two active weak references")
  counter = 0;
  for (o in hashTable)
    {
      counter++;
    }
  PASS(counter == 2,
    "Table fast enumeration sees two active weak references")
  PASS([[hashTable allObjects] count] == 2,
    "Table count has active weak reference")

  [arp2 release]; arp2 = nil;

  counter = 0;
  e = [hashTable objectEnumerator];
  while (nil != (o = [e nextObject]))
    {
      counter++;
    }
  PASS(counter == 0,
    "Table standard enumeration does not see deallocated weak reference")
  counter = 0;
  for (o in hashTable)
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
