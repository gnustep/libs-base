#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSString.h>

/* An observer may be removed, and then deallocated, from inside another
 * observer's -observeValueForKeyPath:... for the same change.  The key path
 * observer does not retain its observer, so once removed and deallocated it
 * must not be messaged for the change still being delivered — removal
 * guarantees that no further notifications arrive.
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

static int victimNotifications = 0;

@interface Victim : NSObject
@end

@implementation Victim
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  victimNotifications++;
}
@end

/* Removes and releases the victim while a change is being delivered. */
@interface Remover : NSObject
{
@public
  Subject *subject;
  Victim  *victim;
  int	   count;
}
@end

@implementation Remover
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  count++;
  if (victim)
    {
      [subject removeObserver: victim forKeyPath: @"value"];
      DESTROY(victim);
    }
}
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  Subject		*subject;
  Remover		*remover;

  /* The victim is registered first so that the change reaches the remover
   * before it: notifications are delivered in reverse order of registration,
   * so when the victim's turn comes it has already been deallocated. */
  subject = AUTORELEASE([Subject new]);
  remover = AUTORELEASE([Remover new]);
  remover->subject = subject;
  remover->victim = [Victim new];
  [subject addObserver: remover->victim
	    forKeyPath: @"value"
	       options: NSKeyValueObservingOptionNew
	       context: NULL];
  [subject addObserver: remover
	    forKeyPath: @"value"
	       options: NSKeyValueObservingOptionNew
	       context: NULL];
  [subject setValue: 1];
  PASS(0 == victimNotifications,
    "an observer removed and deallocated during delivery is not messaged")
  PASS(1 == remover->count,
    "the observer which removed it is notified once")
  [subject setValue: 2];
  PASS(2 == remover->count,
    "and keeps receiving changes")
  PASS(0 == victimNotifications,
    "while the deallocated observer stays unnotified")
  [subject removeObserver: remover forKeyPath: @"value"];

  [arp release]; arp = nil;
  return 0;
}
