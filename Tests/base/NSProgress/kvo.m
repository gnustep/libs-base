/* Test KVO support in NSProgress */

#include "Foundation/NSException.h"
#include "GNUstepBase/GNUstep.h"
#import <Foundation/NSProgress.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSKeyValueObserving.h>
#import "ObjectTesting.h"

@interface ParentObserver : NSObject
{
@public
    uint32_t _counter;
}
@end

/* Order of events as seen in macOS 15.5.
 */
@implementation ParentObserver
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  switch (_counter)
  {
    case 0: // parent change totalUnitCount (prior)
        PASS(context == (void *)1, "Observation is parent 'totalUnitCount'")
        break;
    case 1: // parent change co
        PASS(context == (void *)1, "Observation is parent 'totalUnitCount'")
        break;
    case 2: // parent change completedUnitCount (prior)
        PASS((int64_t)context == 2, "Observation is parent 'completedUnitCount'")
        break;
    case 3: // parent change finished (prior)
        PASS((int64_t)context == 3, "Observation is parent 'finished'")
        break;
    case 4: // parent change finished
        PASS((int64_t)context == 3, "Observation is parent 'finished'")
        break;
    case 5: // parent change completedUnitCount
        PASS((int64_t)context == 2, "Observation is parent 'completedUnitCount'")
        break;
    default:
        PASS(0, "Unexpected KVO change event");
  }
  _counter += 1;
}
@end

@interface ChildObserver : NSObject
{
@public
    uint32_t _counter;
}
@end

@implementation ChildObserver
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
  // The KVO implementation of GCC is _special_ and does not behave according to
  // the specification.
  #if defined(__GNUC__)
  testHopeful = YES;
  #endif
 
  switch (_counter)
  {
    case 0: // child change fractionCompleted (prior)
        PASS(context == (void *)3, "Observation is child 'fractionCompleted'")
        break;
    case 1: // child change completedUnitCount (prior)
        PASS(context == (void *)2, "Observation is child 'completedUnitCount'")
        break;
    case 2: // child change finished (prior)
        PASS(context == (void *)4, "Observation is child 'finished'")
        break;
    case 3: // child change finished
        PASS(context == (void *)4, "Observation is child 'finished'")
        break;
    case 4: // child change completedUnitCount
        PASS(context == (void *)2, "Observation is child 'completedUnitCount'")
        break;
    case 5: // child change fractionCompleted
        PASS(context == (void *)3, "Observation is child 'fractionCompleted'")
        break;
    default:
        PASS(0, "Unexpected KVO change event");
  }
  _counter += 1;

  #if defined(__GNUC__)
  testHopeful = NO;
  #endif
}
@end

int main(void)
{
    ENTER_POOL
    ParentObserver *parentObserver = [ParentObserver new];
    NSProgress *parent = [[NSProgress alloc] initWithParent: nil userInfo: nil];
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew |
            NSKeyValueObservingOptionOld | NSKeyValueObservingOptionPrior;

    [parent addObserver: parentObserver
             forKeyPath: @"totalUnitCount"
            options: options
            context: (void *)1];
    [parent addObserver: parentObserver
             forKeyPath: @"completedUnitCount"
            options: options
            context: (void *)2];
    [parent addObserver: parentObserver
             forKeyPath: @"finished"
            options: options
            context: (void *)3];

    [parent setTotalUnitCount: 10]; // First set of notifications
    [parent becomeCurrentWithPendingUnitCount: 10];

    ChildObserver *childObserver = [ChildObserver new];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];

    [child addObserver: childObserver
             forKeyPath: @"completedUnitCount"
            options: options
            context: (void *)2];
    [child addObserver: childObserver
             forKeyPath: @"fractionCompleted"
            options: options
            context: (void *)3];
    [child addObserver: childObserver
             forKeyPath: @"finished"
            options: options
            context: (void *)4];

    [child setCompletedUnitCount: 10]; // Second set of notifications
    [parent resignCurrent];

    [child removeObserver: childObserver forKeyPath: @"completedUnitCount"];
    [child removeObserver: childObserver forKeyPath: @"fractionCompleted"];
    [child removeObserver: childObserver forKeyPath: @"finished"];
    [childObserver release];

    [parent removeObserver: parentObserver forKeyPath: @"totalUnitCount"];
    [parent removeObserver: parentObserver forKeyPath: @"completedUnitCount"];
    [parent removeObserver: parentObserver forKeyPath: @"finished"];
    [parentObserver release];
    [parent release];
  LEAVE_POOL
  return 0;
}
