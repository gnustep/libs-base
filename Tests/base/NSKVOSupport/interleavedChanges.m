#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>

/* Changes of two keys of one object may overlap without being nested:
 * willChange A, willChange B, didChange A, didChange B.  Each didChange has
 * to complete the change of its own key.
 */

@interface Subject : NSObject
{
  int _a;
  int _b;
}
@end

@implementation Subject
- (int) a { return _a; }
- (void) setA: (int)v { _a = v; }
- (int) b { return _b; }
- (void) setB: (int)v { _b = v; }
@end

@interface Recorder : NSObject
{
@public
  int		count;
  NSDictionary	*last;
}
@end

@implementation Recorder
- (void) dealloc
{
  [last release];
  [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  if (nil != [change objectForKey: NSKeyValueChangeNotificationIsPriorKey])
    {
      return;
    }
  count++;
  ASSIGN(last, change);
}
@end

/* Announces a change of b around every change of a, the way a value derived
 * from a is announced by an object observing itself. */
@interface Follower : NSObject
@end

@implementation Follower
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  if (nil != [change objectForKey: NSKeyValueChangeNotificationIsPriorKey])
    {
      [object willChangeValueForKey: @"b"];
    }
  else
    {
      [object setB: [object a] * 10];
      [object didChangeValueForKey: @"b"];
    }
}
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSKeyValueObservingOptions options;
  Subject		*subject;
  Recorder		*ra;
  Recorder		*rb;
  Follower		*follower;

  options = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;

  subject = AUTORELEASE([Subject new]);
  ra = AUTORELEASE([Recorder new]);
  rb = AUTORELEASE([Recorder new]);
  [subject setA: 1];
  [subject setB: 1];
  [subject addObserver: ra forKeyPath: @"a" options: options context: NULL];
  [subject addObserver: rb forKeyPath: @"b" options: options context: NULL];

  [subject willChangeValueForKey: @"a"];
  [subject willChangeValueForKey: @"b"];
  [subject setA: 2];
  [subject didChangeValueForKey: @"a"];
  [subject setB: 3];
  [subject didChangeValueForKey: @"b"];
  PASS(1 == ra->count,
    "the observer of the key changed first is notified")
  PASS(1 == rb->count,
    "the observer of the key changed second is notified")
  PASS_EQUAL([ra->last objectForKey: NSKeyValueChangeOldKey],
    [NSNumber numberWithInt: 1], "the first key has its own old value")
  PASS_EQUAL([ra->last objectForKey: NSKeyValueChangeNewKey],
    [NSNumber numberWithInt: 2], "the first key has its own new value")
  PASS_EQUAL([rb->last objectForKey: NSKeyValueChangeOldKey],
    [NSNumber numberWithInt: 1], "the second key has its own old value")
  PASS_EQUAL([rb->last objectForKey: NSKeyValueChangeNewKey],
    [NSNumber numberWithInt: 3], "the second key has its own new value")

  [subject setA: 4];
  [subject setB: 5];
  PASS(2 == ra->count,
    "the observer of the key changed first is notified of a later change")
  PASS(2 == rb->count,
    "the observer of the key changed second is notified of a later change")

  [subject removeObserver: ra forKeyPath: @"a"];
  [subject removeObserver: rb forKeyPath: @"b"];

  /* The same overlap, set off by an observer with the prior option. */
  subject = AUTORELEASE([Subject new]);
  ra = AUTORELEASE([Recorder new]);
  rb = AUTORELEASE([Recorder new]);
  follower = AUTORELEASE([Follower new]);
  [subject addObserver: follower
	    forKeyPath: @"a"
	       options: NSKeyValueObservingOptionPrior
	       context: NULL];
  [subject addObserver: ra forKeyPath: @"a" options: options context: NULL];
  [subject addObserver: rb forKeyPath: @"b" options: options context: NULL];

  [subject setA: 1];
  PASS(1 == ra->count,
    "an observer of a key announced from a prior notification is notified")
  PASS(1 == rb->count,
    "and so is the observer of the key it announces")
  [subject setA: 2];
  PASS(2 == ra->count && 2 == rb->count,
    "both keep being notified of later changes")
  PASS_EQUAL([rb->last objectForKey: NSKeyValueChangeOldKey],
    [NSNumber numberWithInt: 10], "the announced key has its old value")
  PASS_EQUAL([rb->last objectForKey: NSKeyValueChangeNewKey],
    [NSNumber numberWithInt: 20], "the announced key has its new value")

  [subject removeObserver: follower forKeyPath: @"a"];
  [subject removeObserver: ra forKeyPath: @"a"];
  [subject removeObserver: rb forKeyPath: @"b"];

  [arp release]; arp = nil;
  return 0;
}
