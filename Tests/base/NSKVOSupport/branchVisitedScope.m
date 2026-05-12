#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface BVSLeaf : NSObject
@property (nonatomic, assign) NSInteger value;
@property (nonatomic, assign) BOOL flag;
@end

@implementation BVSLeaf
@end

@interface BVSNode : NSObject
@property (nonatomic, retain) BVSLeaf *leaf;
@property (nonatomic, readonly) NSInteger score;
@end

@implementation BVSNode
+ (NSSet *) keyPathsForValuesAffectingScore
{
  return [NSSet setWithObject: @"leaf.value"];
}
- (NSInteger) score
{
  return self.leaf.value;
}
@end

@interface BVSHolder : NSObject
@property (nonatomic, retain) BVSNode *node;
@end
@implementation BVSHolder
@end

@interface BVSRoot : NSObject
@property (nonatomic, retain) BVSHolder *holder;
@property (nonatomic, readonly) BVSNode *selected;
@property (nonatomic, readonly) BOOL derived;
@end

@implementation BVSRoot
+ (NSSet *) keyPathsForValuesAffectingSelected
{
  return [NSSet setWithObject: @"holder.node"];
}
+ (NSSet *) keyPathsForValuesAffectingDerived
{
  return [NSSet setWithObjects: @"selected.score", @"selected.leaf.flag", nil];
}
- (BVSNode *) selected
{
  return self.holder.node;
}
- (BOOL) derived
{
  return (self.selected.score > 0) && self.selected.leaf.flag;
}
@end

@interface BVSObserver : NSObject
{
@public
  NSUInteger calls;
}
@end

@implementation BVSObserver
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

  BVSRoot *root = AUTORELEASE([BVSRoot new]);
  root.holder = AUTORELEASE([BVSHolder new]);

  BVSLeaf *leaf = AUTORELEASE([BVSLeaf new]);
  leaf.value = 1;
  leaf.flag = YES;
  BVSNode *node = AUTORELEASE([BVSNode new]);
  node.leaf = leaf;

  BVSObserver *observer = AUTORELEASE([BVSObserver new]);
  [root addObserver: observer
         forKeyPath: @"derived"
            options: 0
            context: NULL];

  // Repeatedly rematerialize the shared dependency path.
  for (NSUInteger i = 0; i < 25; i++)
    {
      root.holder.node = nil;
      root.holder.node = node;
    }

  observer->calls = 0;
  leaf.value = 2;
  PASS(observer->calls == 1,
       "Single leaf mutation should emit one derived notification");

  [root removeObserver: observer forKeyPath: @"derived"];
  DESTROY(pool);
  return 0;
}
