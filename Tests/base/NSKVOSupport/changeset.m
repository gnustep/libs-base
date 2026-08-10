#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSString.h>

/* An observer may be registered or removed from inside a notification, and a
 * prior notification is delivered while the change is in progress.  What is
 * registered at the end of a change has to be what receives the next one.
 */

@interface Subject : NSObject
{
  int _value;
  int _other;
}
@end

@implementation Subject
- (int) value { return _value; }
- (void) setValue: (int)v { _value = v; }
- (int) other { return _other; }
- (void) setOther: (int)v { _other = v; }
@end

@interface Counter : NSObject
{
@public
  int count;
}
@end

@implementation Counter
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  count++;
}
@end

/* Registers or removes another observer while a change is in progress. */
@interface Meddler : NSObject
{
@public
  Subject  *subject;
  Counter  *other;
  NSString *key;
  BOOL	    removes;
  BOOL	    done;
  int	    count;
}
@end

@implementation Meddler
- (void) observeValueForKeyPath: (NSString *)keyPath
		       ofObject: (id)object
			 change: (NSDictionary *)change
			context: (void *)context
{
  count++;
  if (done
    || nil == [change objectForKey: NSKeyValueChangeNotificationIsPriorKey])
    {
      return;
    }
  done = YES;
  if (removes)
    {
      [subject removeObserver: other forKeyPath: key];
    }
  else
    {
      [subject addObserver: other
		forKeyPath: key
		   options: NSKeyValueObservingOptionNew
		   context: NULL];
    }
}
@end

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  Subject		*subject;
  Counter		*counter;
  Meddler		*meddler;

  /* Registered while the change is in progress. */
  subject = AUTORELEASE([Subject new]);
  counter = AUTORELEASE([Counter new]);
  meddler = AUTORELEASE([Meddler new]);
  meddler->subject = subject;
  meddler->other = counter;
  meddler->key = @"value";
  meddler->removes = NO;
  [subject addObserver: meddler
	    forKeyPath: @"value"
	       options: NSKeyValueObservingOptionNew
		       | NSKeyValueObservingOptionPrior
	       context: NULL];
  [subject setValue: 1];
  [subject setValue: 2];
  PASS(counter->count > 0,
    "an observer registered during a change is sent a later change")
  [subject setValue: 3];
  PASS(counter->count > 1,
    "and every change after that one as well")
  [subject removeObserver: meddler forKeyPath: @"value"];
  [subject removeObserver: counter forKeyPath: @"value"];

  /* Removed while the change is in progress.  The victim is registered first
   * so that the change reaches it before the observer which removes it. */
  subject = AUTORELEASE([Subject new]);
  counter = AUTORELEASE([Counter new]);
  meddler = AUTORELEASE([Meddler new]);
  meddler->subject = subject;
  meddler->other = counter;
  meddler->key = @"value";
  meddler->removes = YES;
  [subject addObserver: counter
	    forKeyPath: @"value"
	       options: NSKeyValueObservingOptionNew
	       context: NULL];
  [subject addObserver: meddler
	    forKeyPath: @"value"
	       options: NSKeyValueObservingOptionNew
		       | NSKeyValueObservingOptionPrior
	       context: NULL];
  [subject setValue: 1];
  [subject setValue: 2];
  PASS(0 == counter->count,
    "an observer removed during a change is sent nothing")
  PASS(meddler->count > 2,
    "and the observer which removed it keeps receiving changes")
  [subject removeObserver: meddler forKeyPath: @"value"];

  /* A key other than the one being changed is unaffected. */
  subject = AUTORELEASE([Subject new]);
  counter = AUTORELEASE([Counter new]);
  meddler = AUTORELEASE([Meddler new]);
  meddler->subject = subject;
  meddler->other = counter;
  meddler->key = @"other";
  meddler->removes = NO;
  [subject addObserver: meddler
	    forKeyPath: @"value"
	       options: NSKeyValueObservingOptionNew
		       | NSKeyValueObservingOptionPrior
	       context: NULL];
  [subject setValue: 1];
  [subject setOther: 1];
  PASS(counter->count > 0,
    "an observer registered for another key during a change is sent its own")
  [subject removeObserver: meddler forKeyPath: @"value"];
  [subject removeObserver: counter forKeyPath: @"other"];

  [arp release]; arp = nil;
  return 0;
}
