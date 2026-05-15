#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface CDOObserver : NSObject
{
@public
  NSUInteger calls;
}
@end

@implementation CDOObserver
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  (void)keyPath;
  (void)object;
  (void)change;
  (void)context;
  calls++;
}
@end

@interface CDODirectCycleRoot : NSObject
{
  NSInteger _leaf;
}
@property (nonatomic, assign) NSInteger leaf;
@property (nonatomic, readonly) NSInteger a;
@property (nonatomic, readonly) NSInteger b;
@property (nonatomic, readonly) NSInteger derived;
@end

@implementation CDODirectCycleRoot
@synthesize leaf = _leaf;
+ (NSSet *) keyPathsForValuesAffectingA
{
  return [NSSet setWithObject: @"b"];
}
+ (NSSet *) keyPathsForValuesAffectingB
{
  return [NSSet setWithObject: @"a"];
}
+ (NSSet *) keyPathsForValuesAffectingDerived
{
  return [NSSet setWithObjects: @"a", @"leaf", nil];
}
- (NSInteger) a
{
  return self.leaf;
}
- (NSInteger) b
{
  return self.leaf;
}
- (NSInteger) derived
{
  return self.a + self.leaf;
}
@end

@interface CDOThreeCycleRoot : NSObject
{
  NSInteger _leaf;
}
@property (nonatomic, assign) NSInteger leaf;
@property (nonatomic, readonly) NSInteger x;
@property (nonatomic, readonly) NSInteger y;
@property (nonatomic, readonly) NSInteger z;
@property (nonatomic, readonly) NSInteger derived;
@end

@implementation CDOThreeCycleRoot
@synthesize leaf = _leaf;
+ (NSSet *) keyPathsForValuesAffectingX
{
  return [NSSet setWithObject: @"y"];
}
+ (NSSet *) keyPathsForValuesAffectingY
{
  return [NSSet setWithObject: @"z"];
}
+ (NSSet *) keyPathsForValuesAffectingZ
{
  return [NSSet setWithObject: @"x"];
}
+ (NSSet *) keyPathsForValuesAffectingDerived
{
  return [NSSet setWithObjects: @"x", @"leaf", nil];
}
- (NSInteger) x
{
  return self.leaf;
}
- (NSInteger) y
{
  return self.leaf;
}
- (NSInteger) z
{
  return self.leaf;
}
- (NSInteger) derived
{
  return self.x + self.leaf;
}
@end

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);

#if !defined(clang)
  testHopeful = YES;
#endif

  {
    CDODirectCycleRoot *root = AUTORELEASE([CDODirectCycleRoot new]);
    CDOObserver *observer = AUTORELEASE([CDOObserver new]);
    root.leaf = 1;

    [root addObserver: observer forKeyPath: @"derived" options: 0 context: NULL];

    observer->calls = 0;
    root.leaf = 2;
    PASS(observer->calls == 1,
         "Direct A<->B cycle: leaf mutation notifies derived exactly once");

    [root removeObserver: observer forKeyPath: @"derived"];
  }

  {
    CDOThreeCycleRoot *root = AUTORELEASE([CDOThreeCycleRoot new]);
    CDOObserver *observer = AUTORELEASE([CDOObserver new]);
    root.leaf = 5;

    [root addObserver: observer forKeyPath: @"derived" options: 0 context: NULL];

    observer->calls = 0;
    root.leaf = 6;
    PASS(observer->calls == 1,
         "Three-node X->Y->Z->X cycle: leaf mutation notifies derived exactly once");

    [root removeObserver: observer forKeyPath: @"derived"];
  }

#if !defined(clang)
  testHopeful = NO;
#endif

  DESTROY(pool);
  return 0;
}
