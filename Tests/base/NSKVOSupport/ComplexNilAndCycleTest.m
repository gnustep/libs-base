#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@class BNode;

@interface CNode : NSObject
{
  NSInteger _f;
  NSObject *_d;
  BNode *_b;
}
@property (nonatomic, retain) NSObject *d;
@property (nonatomic, retain) BNode *b;
@property (nonatomic, assign) NSInteger f;
@end
@implementation CNode
@synthesize d = _d;
@synthesize b = _b;
- (NSInteger) f
{
  return _f;
}
- (void) setF: (NSInteger)f
{
  BOOL notifyD = (self.d != nil);
  [self willChangeValueForKey: @"f"];
  if (notifyD)
    {
      [self willChangeValueForKey: @"d"];
    }
  _f = f;
  if (notifyD)
    {
      [self didChangeValueForKey: @"d"];
    }
  [self didChangeValueForKey: @"f"];
}
@end

@interface BNode : NSObject
{
  CNode *_c;
  NSInteger _e;
}
@property (nonatomic, retain) CNode *c;
@property (nonatomic, assign) NSInteger e;
@end
@implementation BNode
@synthesize c = _c;
@synthesize e = _e;
@end

@interface ANode : NSObject
{
  BNode *_b;
  CNode *_c;
}
@property (nonatomic, retain) BNode *b;
@property (nonatomic, retain) CNode *c;
@end
@implementation ANode
@synthesize b = _b;
@synthesize c = _c;
@end

@interface RootNode : NSObject
{
  ANode *_a;
}
@property (nonatomic, retain) ANode *a;
@property (nonatomic, readonly) BOOL x;
@end
@implementation RootNode
@synthesize a = _a;
+ (NSSet *) keyPathsForValuesAffectingX
{
  return [NSSet setWithObjects: @"a.b.c.d", @"a.c.b.e", nil];
}
- (BOOL) x
{
  return (self.a.b.c.d != nil) || (self.a.c.b.e > 0);
}
@end

@interface TestObserver : NSObject
{
@public
  NSUInteger calls;
}
@end
@implementation TestObserver
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

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);

  BNode *b = AUTORELEASE([BNode new]);
  b.e = 1;

  CNode *cForA = AUTORELEASE([CNode new]);
  cForA.b = b;

  CNode *cForB = AUTORELEASE([CNode new]);
  cForB.d = nil;
  cForB.f = 10;

  ANode *a = AUTORELEASE([ANode new]);
  a.b = b;
  a.c = cForA;
  b.c = cForB;

  RootNode *root = AUTORELEASE([RootNode new]);
  root.a = a;

  TestObserver *obs = AUTORELEASE([TestObserver new]);
  [root addObserver: obs forKeyPath: @"x" options: 0 context: NULL];

  obs->calls = 0;
  b.e = 2;
  PASS(obs->calls == 1, "updating e should trigger notification");

  CNode *newCForB = AUTORELEASE([CNode new]);
  newCForB.d = AUTORELEASE([NSObject new]);
  newCForB.f = 100;
  obs->calls = 0;
  b.c = newCForB;
  PASS(obs->calls == 1,
       "updating c with a new object where d is non-nil should trigger notification");

  obs->calls = 0;
  b.e = 3;
  PASS(obs->calls == 1, "updating e should still notify");

  obs->calls = 0;
  newCForB.f = 101;
  PASS(obs->calls == 1, "updating f should notify");

  obs->calls = 0;
  newCForB.d = nil;
  PASS(obs->calls == 1, "setting d to nil again should notify");

  obs->calls = 0;
  newCForB.f = 102;
  PASS(obs->calls == 0, "updating f should not notify after d became nil");

  obs->calls = 0;
  b.c = nil;
  PASS(obs->calls == 1, "setting c to nil should notify");

  obs->calls = 0;
  b.e = 4;
  PASS(obs->calls == 1, "updating e should still notify");

  [root removeObserver: obs forKeyPath: @"x"];
  DESTROY(pool);
  return 0;
}
