#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface VACLeaf : NSObject
{
  NSInteger _value;
  BOOL _flag;
}
@property (nonatomic, assign) NSInteger value;
@property (nonatomic, assign) BOOL flag;
@end
@implementation VACLeaf
@synthesize value = _value;
@synthesize flag = _flag;
@end

@interface VACNode : NSObject
{
  VACLeaf *_leaf;
}
@property (nonatomic, retain) VACLeaf *leaf;
@property (nonatomic, readonly) NSInteger score;
@end
@implementation VACNode
@synthesize leaf = _leaf;
+ (NSSet *) keyPathsForValuesAffectingScore
{
  return [NSSet setWithObject: @"leaf.value"];
}
- (NSInteger) score
{
  return self.leaf.value;
}
@end

@interface VACHolder : NSObject
{
  VACNode *_node;
}
@property (nonatomic, retain) VACNode *node;
@end
@implementation VACHolder
@synthesize node = _node;
@end

@interface VACRoot : NSObject
{
  VACHolder *_holder;
}
@property (nonatomic, retain) VACHolder *holder;
@property (nonatomic, readonly) VACNode *selectedA;
@property (nonatomic, readonly) VACNode *selectedB;
@property (nonatomic, readonly) BOOL derived;
@end

@implementation VACRoot
@synthesize holder = _holder;
+ (NSSet *) keyPathsForValuesAffectingSelectedA
{
  return [NSSet setWithObject: @"holder.node"];
}
+ (NSSet *) keyPathsForValuesAffectingSelectedB
{
  // Intentionally identical dependency text as selectedA.
  return [NSSet setWithObject: @"holder.node"];
}
+ (NSSet *) keyPathsForValuesAffectingDerived
{
  return [NSSet setWithObjects: @"selectedA.leaf.flag", @"selectedB.score", nil];
}
- (VACNode *) selectedA { return self.holder.node; }
- (VACNode *) selectedB { return self.holder.node; }
- (BOOL) derived
{
  return self.selectedA.leaf.flag && (self.selectedB.score > 0);
}
@end

@interface VACObserver : NSObject
{
@public
  NSUInteger calls;
}
@end
@implementation VACObserver
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  (void) keyPath; (void) object; (void) change; (void) context;
  calls++;
}
@end

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);

#if !defined(clang)
  testHopeful = YES;
#endif

// testcases here

  VACRoot *root = AUTORELEASE([VACRoot new]);
  root.holder = AUTORELEASE([VACHolder new]);

  VACLeaf *leaf = AUTORELEASE([VACLeaf new]);
  leaf.value = 1;
  leaf.flag = YES;
  VACNode *node = AUTORELEASE([VACNode new]);
  node.leaf = leaf;

  VACObserver *obs = AUTORELEASE([VACObserver new]);
  [root addObserver: obs forKeyPath: @"derived" options: 0 context: NULL];

  // Materialize graph after observer registration while holder.node is nil.
  root.holder.node = node;

  obs->calls = 0;
  leaf.value = 2;
  PASS(obs->calls == 1,
       "selectedB.score branch should be wired (leaf.value notifies derived)");

  obs->calls = 0;
  leaf.flag = NO;
  PASS(obs->calls == 1,
       "selectedA.leaf.flag branch should be wired (leaf.flag notifies derived)");

  [root removeObserver: obs forKeyPath: @"derived"];

#if !defined(clang)
  testHopeful = NO;
#endif

  DESTROY(pool);
  return 0;
}
