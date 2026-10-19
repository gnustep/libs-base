#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSString.h>

/* An observer's handling of a notification may release the last reference to
 * the observer itself, e.g. by releasing an object which owns it.  The
 * observer must stay alive until its method returns.
 */

@interface Subject : NSObject
{
  int _value;
}
@end

@implementation Subject
- (int) value { return _value; }
- (void) setValue: (int)v { _value = v; }
@end

static id	owner = nil;	/* the only reference to the observer */
static int	notifications = 0;
static BOOL	deallocated = NO;
static BOOL	aliveAfterRelease = NO;

@interface SelfReleasingObserver : NSObject
{
@public
  Subject	*subject;
}
@end

@implementation SelfReleasingObserver
- (void) dealloc
{
  deallocated = YES;
  [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  notifications++;
  [subject removeObserver: self forKeyPath: @"value"];
  DESTROY(owner);
  aliveAfterRelease = !deallocated;
}
@end

/* An observer which is being deallocated must no longer be notified.  Here
 * its own -dealloc changes the observed object before removing itself.
 */
static BOOL	notifiedWhileDeallocating = NO;

@interface DeallocatingObserver : NSObject
{
@public
  Subject	*subject;
}
@end

@implementation DeallocatingObserver
- (void) dealloc
{
  [subject setValue: 2];
  [subject removeObserver: self forKeyPath: @"value"];
  [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  notifiedWhileDeallocating = YES;
}
@end

static void
releaseWhileNotified(NSKeyValueObservingOptions options)
{
  NSAutoreleasePool		*arp = [NSAutoreleasePool new];
  Subject			*subject = [Subject new];
  SelfReleasingObserver		*observer = [SelfReleasingObserver new];

  notifications = 0;
  deallocated = NO;
  aliveAfterRelease = NO;
  observer->subject = subject;
  owner = observer;
  [subject addObserver: observer
	    forKeyPath: @"value"
	       options: options
	       context: NULL];
  if (!(options & NSKeyValueObservingOptionInitial))
    {
      [subject setValue: 1];
    }
  [arp release];
  [subject release];
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];

  releaseWhileNotified(NSKeyValueObservingOptionNew);
  PASS(1 == notifications && aliveAfterRelease,
    "an observer releasing itself in a change notification lives until it returns")
  PASS(deallocated, "and is deallocated afterwards")

  releaseWhileNotified(NSKeyValueObservingOptionPrior);
  PASS(1 == notifications && aliveAfterRelease,
    "an observer releasing itself in a prior notification lives until it returns")
  PASS(deallocated, "and is deallocated afterwards")

  releaseWhileNotified(NSKeyValueObservingOptionInitial);
  PASS(1 == notifications && aliveAfterRelease,
    "an observer releasing itself in the initial notification lives until it returns")
  PASS(deallocated, "and is deallocated afterwards")

  {
    Subject		*subject = [Subject new];
    DeallocatingObserver	*observer = [DeallocatingObserver new];

    observer->subject = subject;
    [subject addObserver: observer
	      forKeyPath: @"value"
		 options: NSKeyValueObservingOptionNew
		 context: NULL];
    [observer release];
    PASS(!notifiedWhileDeallocating,
      "an observer is no longer notified once it is being deallocated")
    [subject release];
  }

  [arp release]; arp = nil;
  return 0;
}
