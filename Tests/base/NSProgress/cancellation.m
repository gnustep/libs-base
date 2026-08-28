/* Test propragation of progress cancellation to children */

#import <Foundation/NSObject.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

@interface Observer : NSObject
{
    @public
    int observations;
}

@end

@implementation Observer

- (void) observeValueForKeyPath:(NSString *) keyPath 
                       ofObject:(id) object 
                         change:(NSDictionary *) change 
                        context:(void *) context {
    observations += 1;
}

@end

void checkPropagationExplicitChildren(void) {
/*
 *        ┌──────────┐
 *        │  PARENT  │
 *        └──────────┘
 *              │
 *       ┌──────┴──────┐
 *       ▼             ▼
 * ┌──────────┐  ┌──────────┐
 * │  CHILD0  │  │  CHILD1  │
 * └──────────┘  └──────────┘
 *                     │
 *                     └────┐
 *                          ▼
 *                    ┌──────────┐
 *                    │  CHILD2  │
 *                    └──────────┘
 */
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child0 = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *child1 = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *child2 = [NSProgress progressWithTotalUnitCount: 5];

    [parent setCancellable: NO];

    #if __has_feature(blocks)
    bool __block cancelationHandlerParentCalled = false;
    bool __block cancelationHandlerChild2Called = false;

    [parent setCancellationHandler:^(void){
      cancelationHandlerParentCalled = true;
    }];
    [child2 setCancellationHandler:^(void){
      cancelationHandlerChild2Called = true;
    }];
    #endif

    /* child0 and child1 constitude 100% of the unit count of the parent */
    [parent addChild: child0 withPendingUnitCount: 50];
    [parent addChild: child1 withPendingUnitCount: 50];
    [child1 addChild: child2 withPendingUnitCount: 5];

    [child2 setCompletedUnitCount: 2];
    [child1 setCompletedUnitCount: 5];
    [child0 setCompletedUnitCount: 10];

    PASS([child0 isFinished], "child0 is finished");

    /* Only unfinished progresses are cancelled */
    [parent cancel];
    PASS([parent isCancelled], "parent is cancelled");
    PASS([child0 isCancelled] == NO, "child0 is not cancelled");
    PASS([child1 isCancelled], "child1 is cancelled");
    PASS([child2 isCancelled], "child2 is cancelled");

    
    #if __has_feature(blocks)
    /* Check if the cancelation handlers were called */
    PASS(cancelationHandlerParentCalled, "cancelation handler for parent was called");
    PASS(cancelationHandlerChild2Called, "cancelation handler for child2 was called");
    #endif

    /* Check if we can still modify the completedUnitCount after cancelation
     * This is not documented in the API docs, but behaviour in macOS.
     */
    Observer *o = [[Observer alloc] init];
    [parent addObserver: o forKeyPath: @"completedUnitCount" options: 0 context: NULL];

    int64_t oldParentUnitCount = [parent completedUnitCount];
    [parent setCompletedUnitCount: oldParentUnitCount + 1];
    PASS((oldParentUnitCount + 1) == [parent completedUnitCount], "completedUnitCount can be changed after cancelation");
    PASS(o->observations == 1, "received one KVO notification");

    [parent removeObserver: o forKeyPath: @"completedUnitCount"];
    [o release];

}

int main(void)
{
    ENTER_POOL

    checkPropagationExplicitChildren();

    LEAVE_POOL
    return 0;
}
