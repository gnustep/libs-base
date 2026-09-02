#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCache.h>

/* NSDiscardableContent object that records whether the cache asked it to
 * discard its content.
 */
@interface DiscardableObject : NSObject <NSDiscardableContent>
{
  @public
  BOOL	discarded;
}
@end

@implementation DiscardableObject
- (BOOL) beginContentAccess { return YES; }
- (void) endContentAccess {}
- (void) discardContentIfPossible { discarded = YES; }
- (BOOL) isContentDiscarded { return discarded; }
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSCache		*cache = [[NSCache new] autorelease];
  DiscardableObject	*a = [[DiscardableObject new] autorelease];
  DiscardableObject	*b = [[DiscardableObject new] autorelease];
  DiscardableObject	*c = [[DiscardableObject new] autorelease];

  /* A cache with neither a count limit nor a cost limit is unbounded
   * (both limits default to 0, which means "no limit"), so it must never
   * discard the content of the objects it holds, even discardable ones.
   */
  [cache setObject: a forKey: @"a"];
  [cache setObject: b forKey: @"b"];
  [cache setObject: c forKey: @"c"];

  PASS(NO == [a isContentDiscarded],
    "an unbounded cache does not discard content on insert");
  PASS(NO == [b isContentDiscarded],
    "an unbounded cache leaves later objects' content intact");
  PASS_EQUAL(a, [cache objectForKey: @"a"],
    "the first object is still cached in an unbounded cache");
  PASS_EQUAL(c, [cache objectForKey: @"c"],
    "the last object is still cached in an unbounded cache");

  [arp release]; arp = nil;
  return 0;
}
