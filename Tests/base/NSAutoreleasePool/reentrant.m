#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

static int deallocCount = 0;
static int liveCount = 0;

@interface TestObject : NSObject
@end

@implementation TestObject

- (id) init
{
  self = [super init];
  liveCount++;
  return self;
}

- (void) dealloc
{
  deallocCount++;
  liveCount--;
  [super dealloc];
}
@end

@interface PoolCreatingObject : NSObject
@end

@implementation PoolCreatingObject

- (void) dealloc
{
  NSAutoreleasePool *p = [NSAutoreleasePool new];

  [[[NSObject alloc] init] autorelease];

  [p drain];

  [super dealloc];
}

@end

@interface PoolDrainingObject : NSObject
{
  NSAutoreleasePool *pool;
}
@end

@implementation PoolDrainingObject

- (id) init
{
  self = [super init];

  pool = [NSAutoreleasePool new];
  [[[NSObject alloc] init] autorelease];

  return self;
}

- (void) dealloc
{
  [pool drain];
  [super dealloc];
}
@end

@interface AutoreleasingObject : NSObject
@end

@implementation AutoreleasingObject

- (void) dealloc
{
  [[[NSObject alloc] init] autorelease];
  [super dealloc];
}
@end

@interface RecursivePoolObject : NSObject
{
  int depth;
}
- (id) initWithDepth:(int)d;
@end

@implementation RecursivePoolObject

- (id) initWithDepth: (int)d
{
  self = [super init];
  depth = d;
  return self;
}

- (void) dealloc
{
  if (depth > 0)
    {
      NSAutoreleasePool *p = [NSAutoreleasePool new];

      [[[RecursivePoolObject alloc]
        initWithDepth: depth - 1] autorelease];

      [p drain];
    }

  [super dealloc];
}
@end

@interface BurstObject : NSObject
@end

@implementation BurstObject

- (void) dealloc
{
  int i;

  for (i = 0; i < 10000; i++)
    {
      [[[NSObject alloc] init] autorelease];
    }

  [super dealloc];
}
@end

static NSMutableArray *order;

@interface ReentrantLIFOObject : NSObject
{
  NSString *name;
}
- (id) initWithName: (NSString*)aName;
@end

@implementation ReentrantLIFOObject

- (id) initWithName: (NSString*)aName
{
  self = [super init];
  name = [aName copy];
  return self;
}

- (void) dealloc
{
  [[[NSObject alloc] init] autorelease];

  [order addObject: name];

  [name release];
  [super dealloc];
}

@end



int
main()
{
  ENTER_POOL

  PASS_RUNS(
  {
    NSAutoreleasePool *p = [NSAutoreleasePool new];

    [[[PoolCreatingObject alloc] init] autorelease];

    [p drain];
  },
  "creating and draining a pool during dealloc")

  PASS_RUNS(
  {
    NSAutoreleasePool *p = [NSAutoreleasePool new];

    [[[PoolDrainingObject alloc] init] autorelease];

    [p drain];
  },
  "draining subsidiary pool during dealloc")

  PASS_RUNS(
  {
    NSAutoreleasePool *p = [NSAutoreleasePool new];

    [[[AutoreleasingObject alloc] init] autorelease];

    [p drain];
  },
  "autorelease from dealloc while pool is draining")

  PASS_RUNS(
  {
    NSAutoreleasePool *p = [NSAutoreleasePool new];

    [[[RecursivePoolObject alloc]
	initWithDepth:100] autorelease];

    [p drain];
  },
  "recursive pool creation during deallocation")

  PASS_RUNS(
    {
      NSAutoreleasePool *p = [NSAutoreleasePool new];

      [[[BurstObject alloc] init] autorelease];

      [p drain];
    },
  "large autorelease burst generated during drain")

  PASS_RUNS(
    {
      int i;
      NSAutoreleasePool *p = [NSAutoreleasePool new];

      for (i = 0; i < 1000; i++)
	{
	  [[[PoolCreatingObject alloc] init] autorelease];
	  [[[AutoreleasingObject alloc] init] autorelease];
	  [[[BurstObject alloc] init] autorelease];
	}

      [p drain];
    },
  "mixed reentrant deallocation behaviour")


  order = [NSMutableArray array];

  {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    [[[ReentrantLIFOObject alloc] initWithName: @"1"] autorelease];
    [[[ReentrantLIFOObject alloc] initWithName: @"2"] autorelease];
    [[[ReentrantLIFOObject alloc] initWithName: @"3"] autorelease];

    [pool drain];
  }

  PASS(([order isEqual:
    [NSArray arrayWithObjects: @"3", @"2", @"1", nil]]),
    "LIFO ordering maintained during reentrant deallocation")

  LEAVE_POOL

  return 0;
}


