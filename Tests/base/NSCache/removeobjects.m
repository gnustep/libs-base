#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCache.h>

/* Records the objects the cache announces it is about to evict. */
@interface EvictRecorder : NSObject
{
  @public
  NSMutableArray	*evicted;
  NSCache	*lastCache;
}
@end

@implementation EvictRecorder
- (id) init
{
  if (nil != (self = [super init]))
    {
      evicted = [NSMutableArray new];
    }
  return self;
}
- (void) cache: (NSCache*)cache willEvictObject: (id)obj
{
  lastCache = cache;
  [evicted addObject: obj];
}
- (void) dealloc
{
  RELEASE(evicted);
  [super dealloc];
}
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  START_SET("removeObjectForKey:")
    NSCache	*cache = [[NSCache new] autorelease];

    [cache setObject: @"one" forKey: @"a"];
    [cache setObject: @"two" forKey: @"b"];
    [cache removeObjectForKey: @"a"];
    PASS(nil == [cache objectForKey: @"a"],
      "removeObjectForKey: removes the named object");
    PASS_EQUAL(@"two", [cache objectForKey: @"b"],
      "removeObjectForKey: leaves other objects in place");

    /* Removing an absent key must be a harmless no-op. */
    [cache removeObjectForKey: @"missing"];
    PASS_EQUAL(@"two", [cache objectForKey: @"b"],
      "removeObjectForKey: for an absent key is a no-op");
  END_SET("removeObjectForKey:")

  START_SET("objectForKey: miss")
    NSCache	*cache = [[NSCache new] autorelease];

    PASS(nil == [cache objectForKey: @"nope"],
      "objectForKey: returns nil for an unknown key");
  END_SET("objectForKey: miss")

  START_SET("value overwrite")
    NSCache	*cache = [[NSCache new] autorelease];

    [cache setObject: @"first" forKey: @"k"];
    [cache setObject: @"second" forKey: @"k"];
    PASS_EQUAL(@"second", [cache objectForKey: @"k"],
      "setObject:forKey: replaces the value stored for an existing key");
  END_SET("value overwrite")

  START_SET("accessors")
    NSCache	*cache = [[NSCache new] autorelease];

    PASS(NO == [cache evictsObjectsWithDiscardedContent],
      "evictsObjectsWithDiscardedContent defaults to NO");
    [cache setEvictsObjectsWithDiscardedContent: YES];
    PASS(YES == [cache evictsObjectsWithDiscardedContent],
      "evictsObjectsWithDiscardedContent can be set and read back");

    PASS(nil == [cache delegate], "delegate defaults to nil");
    id del = [[NSObject new] autorelease];
    [cache setDelegate: del];
    PASS(del == [cache delegate], "delegate can be set and read back");
  END_SET("accessors")

  START_SET("delegate eviction callback")
    NSCache		*cache = [[NSCache new] autorelease];
    EvictRecorder	*rec = [[EvictRecorder new] autorelease];

    [cache setDelegate: rec];
    [cache setObject: @"v" forKey: @"k"];
    [cache removeObjectForKey: @"k"];
    PASS(1 == [rec->evicted count],
      "delegate is told about an object removed via removeObjectForKey:");
    PASS_EQUAL(@"v", [rec->evicted lastObject],
      "delegate receives the evicted object");
    PASS(cache == rec->lastCache,
      "delegate receives the sending cache");

    [rec->evicted removeAllObjects];
    [cache setObject: @"x" forKey: @"k1"];
    [cache setObject: @"y" forKey: @"k2"];
    [cache removeAllObjects];
    PASS(2 == [rec->evicted count],
      "delegate is told about every object dropped by removeAllObjects");
  END_SET("delegate eviction callback")

  [arp release]; arp = nil;
  return 0;
}
