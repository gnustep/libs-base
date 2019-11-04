#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSMapTable.h>

int main()
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSMapTable *mapTable = [NSMapTable strongToWeakObjectsMapTable];

  NSAutoreleasePool *arp2 = [NSAutoreleasePool new];

  id testObj = [[[NSObject alloc] init] autorelease];
  [mapTable setObject:testObj forKey:@"test"];
  PASS([mapTable objectForKey:@"test"] != nil, "Table retains active weak reference");

  [arp2 release]; arp2 = nil;

  PASS([mapTable objectForKey:@"test"] == nil, "Table removes dead weak reference");

  [arp release]; arp = nil;
  return 0;
}
