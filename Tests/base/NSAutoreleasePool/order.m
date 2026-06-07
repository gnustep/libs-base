#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

static NSMutableArray *events;

@interface PoolOrderObject : NSObject
{
  NSString *name;
}
- (id) initWithName: (NSString*)aName;
@end

@implementation PoolOrderObject

- (id) initWithName: (NSString*)aName
{
  self = [super init];
  name = [aName copy];
  return self;
}

- (void) dealloc
{
  [events addObject: name];
  [name release];
  [super dealloc];
}

@end

int
main()
{
  START_SET("NSAutoreleasePool cross-pool LIFO ordering")

  events = [NSMutableArray array];

  {
    NSAutoreleasePool *p1 = [NSAutoreleasePool new];
    NSAutoreleasePool *p2 = [NSAutoreleasePool new];
    NSAutoreleasePool *p3 = [NSAutoreleasePool new];

    [events removeAllObjects];

    [[[PoolOrderObject alloc] initWithName: @"p3-a"] autorelease];
    [[[PoolOrderObject alloc] initWithName: @"p3-b"] autorelease];

    [p3 drain];

    [[[PoolOrderObject alloc] initWithName: @"p2-a"] autorelease];
    [[[PoolOrderObject alloc] initWithName: @"p2-b"] autorelease];

    [p2 drain];

    [[[PoolOrderObject alloc] initWithName: @"p1-a"] autorelease];
    [[[PoolOrderObject alloc] initWithName: @"p1-b"] autorelease];

    [p1 drain];

    PASS_EQUAL(events,
      ([NSArray arrayWithObjects:
	@"p3-b",
	@"p3-a",
	@"p2-b",
	@"p2-a",
	@"p1-b",
	@"p1-a",
	nil]),
      "objects released in LIFO order within each pool")
  }


  {
    NSAutoreleasePool *p1 = [NSAutoreleasePool new];
    NSAutoreleasePool *p2 = [NSAutoreleasePool new];
    NSAutoreleasePool *p3 = [NSAutoreleasePool new];

    [events removeAllObjects];

    [[[PoolOrderObject alloc] initWithName: @"p3-a"] autorelease];
    [[[PoolOrderObject alloc] initWithName: @"p3-b"] autorelease];

    [[[PoolOrderObject alloc] initWithName: @"p2-a"] autorelease];
    [[[PoolOrderObject alloc] initWithName: @"p2-b"] autorelease];

    [[[PoolOrderObject alloc] initWithName: @"p1-a"] autorelease];
    [[[PoolOrderObject alloc] initWithName: @"p1-b"] autorelease];

    [p1 drain];

/* Order not guaranteed
    PASS_EQUAL(events,
      ([NSArray arrayWithObjects:
	@"p3-b",
	@"p3-a",
	@"p2-b",
	@"p2-a",
	@"p1-b",
	@"p1-a",
	nil]),
      "objects released in LIFO order within each pool")
*/
    PASS([events count] == 6, "all objects released with parent pool")
  }

  END_SET("NSAutoreleasePool cross-pool LIFO ordering")

  return 0;
}
