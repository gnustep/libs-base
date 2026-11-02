/* Test propragation of progress cancellation to children */

#import <Foundation/NSObject.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"
#include <stdio.h>
#include <stdlib.h>

#if defined(_WIN32)
#include <process.h>
#else
#include <unistd.h>
#endif

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

#if __has_feature(blocks)
/* Handlers are called asynchronously. Waits until the counter reaches the
 * expected value, then a bit longer to catch unexpected additional calls.
 */
static BOOL waitForCount(volatile int *counter, int expected)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 5.0];

    while (*counter < expected && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0.01];
    }
    [NSThread sleepForTimeInterval: 0.1];
    return *counter == expected;
}
#endif

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

    Observer *cancellableObserver = [[Observer alloc] init];

    /* KVO observers are only notified if cancellable changes */
    [parent addObserver: cancellableObserver forKeyPath: @"cancellable" options: 0 context: NULL];
    [parent setCancellable: YES];
    PASS(cancellableObserver->observations == 0, "no KVO notification when cancellable is unchanged");
    [parent setCancellable: NO];
    PASS(cancellableObserver->observations == 1, "received KVO notification for cancellable");
    [parent removeObserver: cancellableObserver forKeyPath: @"cancellable"];
    [cancellableObserver release];

    #if __has_feature(blocks)
    volatile int __block cancelationHandlerParentCalls = 0;
    volatile int __block cancelationHandlerChild2Calls = 0;

    [parent setCancellationHandler:^(void){
      __sync_add_and_fetch(&cancelationHandlerParentCalls, 1);
    }];
    [child2 setCancellationHandler:^(void){
      __sync_add_and_fetch(&cancelationHandlerChild2Calls, 1);
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
    PASS(waitForCount(&cancelationHandlerParentCalls, 1), "cancelation handler for parent was called");
    PASS(waitForCount(&cancelationHandlerChild2Calls, 1), "cancelation handler for child2 was called");
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

void checkRepeatedCancellation(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
    Observer *o = [[Observer alloc] init];

    [parent addChild: child withPendingUnitCount: 10];
    [parent addObserver: o forKeyPath: @"cancelled" options: 0 context: NULL];

    #if __has_feature(blocks)
    volatile int __block parentCalls = 0;
    volatile int __block childCalls = 0;

    [parent setCancellationHandler:^(void){
      __sync_add_and_fetch(&parentCalls, 1);
    }];
    [child setCancellationHandler:^(void){
      __sync_add_and_fetch(&childCalls, 1);
    }];
    PASS([parent cancellationHandler] != nil, "cancellationHandler getter returns handler");
    #endif

    [parent cancel];
    PASS(o->observations == 1, "received KVO notification for cancel");
    #if __has_feature(blocks)
    PASS(waitForCount(&parentCalls, 1), "cancellation handler for parent was called");
    PASS(waitForCount(&childCalls, 1), "cancellation handler for child was called");
    #endif

    /* Like pausing, cancelling again calls the handlers again, without KVO */
    [parent cancel];
    PASS(o->observations == 1, "no KVO notification when cancelling again");
    #if __has_feature(blocks)
    PASS(waitForCount(&parentCalls, 2), "cancellation handler for parent was called again");
    PASS(waitForCount(&childCalls, 2), "cancellation handler for child was called again");
    #endif

    [parent removeObserver: o forKeyPath: @"cancelled"];
    [o release];
}

void checkAddingChildren(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *finishedChild = [NSProgress progressWithTotalUnitCount: 1];

    [parent cancel];

    [parent addChild: child withPendingUnitCount: 10];
    PASS([child isCancelled], "child added to cancelled parent is cancelled");

    [finishedChild setCompletedUnitCount: 1];
    [parent addChild: finishedChild withPendingUnitCount: 10];
    PASS([finishedChild isCancelled], "finished child added to cancelled parent is cancelled");
    PASS([parent completedUnitCount] == 10, "finished child adds its pending unit count");
}

static volatile int adderDone = 0;
static volatile int childrenAdded = 0;
static volatile int childrenAddedAfterCancel = 0;

@interface Adder : NSObject
@end

@implementation Adder

/* Adds children until 100 were added after the parent got cancelled, so
 * that some are added before, while and after it is cancelled.
 */
- (void) addChildren: (NSArray *)args {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSProgress *parent = [args objectAtIndex: 0];
    NSMutableArray *children = [args objectAtIndex: 1];
    int i;

    for (i = 0; i < 100000 && childrenAddedAfterCancel < 100; i++) {
        NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
        BOOL cancelled = [parent isCancelled];

        [children addObject: child];
        [parent addChild: child withPendingUnitCount: 0];
        __sync_add_and_fetch(&childrenAdded, 1);
        if (cancelled) {
            __sync_add_and_fetch(&childrenAddedAfterCancel, 1);
        }
    }
    __sync_add_and_fetch(&adderDone, 1);
    [pool release];
}

@end

void checkConcurrentCancelAndAddChild(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSMutableArray *children = [NSMutableArray array];
    Adder *adder = [[Adder alloc] init];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 30.0];
    BOOL allCancelled = NO;
    NSUInteger i;

    [NSThread detachNewThreadSelector: @selector(addChildren:)
                             toTarget: adder
                           withObject: [NSArray arrayWithObjects: parent, children, nil]];
    while (childrenAdded < 100 && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0.001];
    }
    [parent cancel];
    while (adderDone < 1 && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0.01];
    }
    PASS(adderDone == 1 && childrenAddedAfterCancel == 100,
         "children were added before and after cancelling");
    if (adderDone == 1) {
        allCancelled = YES;
        for (i = 0; i < [children count]; i++) {
            allCancelled = allCancelled && [[children objectAtIndex: i] isCancelled];
        }
        [adder release];
    }
    PASS(allCancelled, "children added while cancelling the parent are all cancelled");
}

int main(void)
{
    ENTER_POOL

    checkPropagationExplicitChildren();
    checkRepeatedCancellation();
    checkAddingChildren();
    checkConcurrentCancelAndAddChild();

    /* The thread adding children still uses them if it did not finish */
    if (adderDone != 1) {
        fflush(stdout);
        fflush(stderr);
        _exit(0);
    }

    LEAVE_POOL
    return 0;
}
