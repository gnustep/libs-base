#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSHashTable.h>
#import "ObjectTesting.h"

@interface MyClass: NSObject
@end

@implementation	MyClass
#if 0
- (oneway void) release
{
  NSLog(@"releasing %u", (unsigned)[self retainCount]);
  [super release];
}
- (id) retain
{
  id	result = [super retain];

  NSLog(@"retained %u", (unsigned)[self retainCount]);
  return result;
}
#endif
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSHashTable		*t;
  MyClass		*o;
  int			c;

  t = [[NSHashTable alloc] initWithOptions: NSHashTableObjectPointerPersonality
				  capacity: 10];

  o = [MyClass new];
  c = [o retainCount];
  PASS(c == 1, "initial retain count is one")

  [t addObject: @"a"];
  [t addObject: o];
  PASS([o retainCount] == c + 1, "add to hash table increments retain count")

//  PASS(NSHashGet(t, o) == o, "object found in table")

  [t removeObject: o];
  PASS([o retainCount] == c, "remove from hash table decrements retain count")

  [arp release]; arp = nil;
  return 0;
}
