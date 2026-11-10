/* Test pausing and resuming of progresses and propagation to children.
 * The expected behaviour was verified on macOS 26.6.2 (25G83).
 */

/* These test the block-based API */
#define GS_SUPPRESS_NON_PORTABLE_CODE_WARNINGS 1

#import <Foundation/NSObject.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSException.h>
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
    volatile int observations;
}

@end

@implementation Observer

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    __sync_add_and_fetch(&observations, 1);
}

@end

/* Finishes the observed progress when it gets paused */
@interface FinishingObserver : NSObject
@end

@implementation FinishingObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    NSProgress *progress = object;

    if ([progress isPaused]) {
        [progress setCompletedUnitCount: [progress totalUnitCount]];
    }
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

void checkPausable(void) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 10];
    Observer *o = [[Observer alloc] init];

    PASS([progress isPausable] == NO, "progress is not pausable by default");
    PASS([progress isPaused] == NO, "progress is not paused by default");

    [progress addObserver: o forKeyPath: @"pausable" options: 0 context: NULL];
    [progress setPausable: YES];
    PASS([progress isPausable], "progress is pausable after setPausable: YES");
    PASS(o->observations == 1, "received KVO notification for pausable");
    [progress setPausable: YES];
    PASS(o->observations == 1, "no KVO notification when pausable is unchanged");
    [progress setPausable: NO];
    PASS([progress isPausable] == NO, "progress is not pausable after setPausable: NO");
    [progress removeObserver: o forKeyPath: @"pausable"];
    [o release];

    /* Like cancellation, pausing works regardless of the pausable flag */
    [progress pause];
    PASS([progress isPaused], "non-pausable progress can be paused");

    [progress resume];
    PASS([progress isPaused] == NO, "progress can be resumed");
}

void checkHandlers(void) {
#if __has_feature(blocks)
    /* __block, so that the handlers stored in it do not retain it */
    NSProgress * __block progress = [NSProgress progressWithTotalUnitCount: 10];
    NSThread *caller = [NSThread currentThread];
    Observer *o = [[Observer alloc] init];
    volatile int __block pausingCalls = 0;
    volatile int __block resumingCalls = 0;
    BOOL __block pausedInPausingHandler = NO;
    BOOL __block pausedInResumingHandler = YES;
    BOOL __block handlerOnCallerThread = NO;

    [progress setPausingHandler: ^(void){
        pausedInPausingHandler = [progress isPaused];
        handlerOnCallerThread |= ([NSThread currentThread] == caller);
        __sync_add_and_fetch(&pausingCalls, 1);
    }];
    [progress setResumingHandler: ^(void){
        pausedInResumingHandler = [progress isPaused];
        handlerOnCallerThread |= ([NSThread currentThread] == caller);
        __sync_add_and_fetch(&resumingCalls, 1);
    }];
    PASS([progress pausingHandler] != nil, "pausingHandler getter returns handler");
    PASS([progress resumingHandler] != nil, "resumingHandler getter returns handler");

    [progress addObserver: o forKeyPath: @"paused" options: 0 context: NULL];

    /* Resuming a progress that is not paused still calls the handler */
    [progress resume];
    PASS(waitForCount(&resumingCalls, 1), "resuming handler called when not paused");
    PASS(o->observations == 0, "no KVO notification when resuming unpaused progress");

    [progress pause];
    PASS(o->observations == 1, "received KVO notification for pause");
    PASS(waitForCount(&pausingCalls, 1), "pausing handler called once");
    PASS(pausedInPausingHandler, "progress is paused when pausing handler runs")
    PASS(handlerOnCallerThread == NO, "handlers are called asynchronously")

    /* Pausing a paused progress calls the handler again, without KVO */
    [progress pause];
    PASS(waitForCount(&pausingCalls, 2), "pausing handler called again when already paused");
    PASS(o->observations == 1, "no KVO notification when pausing paused progress");

    pausedInResumingHandler = YES;
    [progress resume];
    PASS(o->observations == 2, "received KVO notification for resume");
    PASS(waitForCount(&resumingCalls, 2), "resuming handler called");
    PASS(pausedInResumingHandler == NO, "progress is not paused when resuming handler runs");

    [progress removeObserver: o forKeyPath: @"paused"];
    [o release];
#endif
}

void checkSettingHandlers(void) {
#if __has_feature(blocks)
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 10];
    volatile int __block pausingCalls = 0;
    volatile int __block resumingCalls = 0;
    volatile int __block cancellationCalls = 0;

    [progress pause];
    [progress cancel];

    /* Pausing and cancellation handlers are called when set in that state */
    [progress setPausingHandler: ^(void){
        __sync_add_and_fetch(&pausingCalls, 1);
    }];
    [progress setCancellationHandler: ^(void){
        __sync_add_and_fetch(&cancellationCalls, 1);
    }];
    PASS(waitForCount(&pausingCalls, 1), "pausing handler called when set on paused progress");
    PASS(waitForCount(&cancellationCalls, 1), "cancellation handler called when set on cancelled progress");

    /* But not the resuming handler when set on a progress that isn't paused */
    [progress resume];
    [progress setResumingHandler: ^(void){
        __sync_add_and_fetch(&resumingCalls, 1);
    }];
    PASS(waitForCount(&resumingCalls, 0), "resuming handler not called when set on unpaused progress");
#endif
}

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
    Observer *parentObserver = [[Observer alloc] init];
    Observer *child2Observer = [[Observer alloc] init];

    #if __has_feature(blocks)
    volatile int __block pausingHandlerChild2Calls = 0;
    volatile int __block resumingHandlerChild2Calls = 0;

    [child2 setPausingHandler:^(void){
      __sync_add_and_fetch(&pausingHandlerChild2Calls, 1);
    }];
    [child2 setResumingHandler:^(void){
      __sync_add_and_fetch(&resumingHandlerChild2Calls, 1);
    }];
    #endif

    /* child0 and child1 constitute 100% of the unit count of the parent */
    [parent addChild: child0 withPendingUnitCount: 50];
    [parent addChild: child1 withPendingUnitCount: 50];
    [child1 addChild: child2 withPendingUnitCount: 5];

    [child2 setCompletedUnitCount: 2];
    [child1 setCompletedUnitCount: 5];
    [child0 setCompletedUnitCount: 10];

    PASS([child0 isFinished], "child0 is finished");

    [parent addObserver: parentObserver forKeyPath: @"paused" options: 0 context: NULL];
    [child2 addObserver: child2Observer forKeyPath: @"paused" options: 0 context: NULL];

    /* Only unfinished progresses are paused */
    [parent pause];
    PASS([parent isPaused], "parent is paused");
    PASS([child0 isPaused] == NO, "child0 is not paused");
    PASS([child1 isPaused], "child1 is paused");
    PASS([child2 isPaused], "child2 is paused");
    PASS(parentObserver->observations == 1, "received KVO notification for parent");
    PASS(child2Observer->observations == 1, "received KVO notification for child2");

    #if __has_feature(blocks)
    PASS(waitForCount(&pausingHandlerChild2Calls, 1), "pausing handler for child2 was called");
    #endif

    /* Check if we can still modify the completedUnitCount while paused */
    [child2 setCompletedUnitCount: 3];
    PASS([child2 completedUnitCount] == 3, "completedUnitCount can be changed while paused");

    [parent resume];
    PASS([parent isPaused] == NO, "parent is resumed");
    PASS([child1 isPaused] == NO, "child1 is resumed");
    PASS([child2 isPaused] == NO, "child2 is resumed");
    PASS(parentObserver->observations == 2, "received KVO notification for parent resume");
    PASS(child2Observer->observations == 2, "received KVO notification for child2 resume");

    #if __has_feature(blocks)
    PASS(waitForCount(&resumingHandlerChild2Calls, 1), "resuming handler for child2 was called");
    #endif

    /* Pausing a child does not pause its parent */
    [child2 pause];
    PASS([child2 isPaused], "child2 is paused");
    PASS([child1 isPaused] == NO, "child1 is not paused by its child");
    PASS([parent isPaused] == NO, "parent is not paused by its grandchild");

    /* Resuming a parent that isn't paused still resumes its children */
    [parent resume];
    PASS([child2 isPaused] == NO, "child2 is resumed by resuming unpaused parent");
    PASS(parentObserver->observations == 2, "no KVO notification for unpaused parent");

    [parent removeObserver: parentObserver forKeyPath: @"paused"];
    [child2 removeObserver: child2Observer forKeyPath: @"paused"];
    [parentObserver release];
    [child2Observer release];
}

void checkAddingChildren(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *implicitChild;
    NSProgress *finishedChild = [NSProgress progressWithTotalUnitCount: 1];
    NSProgress *cancelledParent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *cancelledChild = [NSProgress progressWithTotalUnitCount: 10];

    [parent pause];

    [parent addChild: child withPendingUnitCount: 10];
    PASS([child isPaused], "child added to paused parent is paused");

    [parent becomeCurrentWithPendingUnitCount: 10];
    implicitChild = [NSProgress progressWithTotalUnitCount: 10];
    [parent resignCurrent];
    PASS([implicitChild isPaused], "implicit child of paused parent is paused");

    [finishedChild setCompletedUnitCount: 1];
    [parent addChild: finishedChild withPendingUnitCount: 10];
    PASS([finishedChild isPaused], "finished child added to paused parent is paused");
    PASS([parent completedUnitCount] == 10, "finished child adds its pending unit count");

    [parent resume];
    PASS([child isPaused] == NO, "child is resumed with parent");
    PASS([implicitChild isPaused] == NO, "implicit child is resumed with parent");

    [cancelledParent cancel];
    [cancelledParent addChild: cancelledChild withPendingUnitCount: 10];
    PASS([cancelledChild isCancelled], "child added to cancelled parent is cancelled");
}

void checkStateInteraction(void) {
    NSProgress *cancelled = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *paused = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *finished = [NSProgress progressWithTotalUnitCount: 1];

    [cancelled cancel];
    [cancelled pause];
    PASS([cancelled isPaused], "cancelled progress can be paused");
    [cancelled resume];
    PASS([cancelled isPaused] == NO, "cancelled progress can be resumed");

    [paused pause];
    [paused cancel];
    PASS([paused isCancelled], "paused progress can be cancelled");
    PASS([paused isPaused], "cancelling does not resume a paused progress");

    [finished setCompletedUnitCount: 1];
    [finished pause];
    PASS([finished isPaused], "finished progress can be paused");
}

void checkChildFinishingWhilePausing(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    FinishingObserver *o = [[FinishingObserver alloc] init];
    NSMutableArray *children = [NSMutableArray array];
    BOOL raised = NO;
    BOOL allFinished = YES;
    BOOL allPaused = YES;
    int i;

    for (i = 0; i < 4; i++) {
        NSProgress *child = [NSProgress progressWithTotalUnitCount: 1];

        [parent addChild: child withPendingUnitCount: 25];
        [child addObserver: o forKeyPath: @"paused" options: 0 context: NULL];
        [children addObject: child];
    }

    /* The children remove themselves from the parent while it pauses them.
     * macOS 26.6.2 deadlocks here because it sends KVO notifications while
     * holding the parent's lock, so this only tests GNUstep's behaviour.
     */
    NS_DURING
        [parent pause];
    NS_HANDLER
        raised = YES;
    NS_ENDHANDLER
    PASS(raised == NO, "children finishing while parent pauses them does not raise");

    for (i = 0; i < 4; i++) {
        NSProgress *child = [children objectAtIndex: i];

        allFinished = allFinished && [child isFinished];
        allPaused = allPaused && [child isPaused];
        [child removeObserver: o forKeyPath: @"paused"];
    }
    PASS(allFinished, "all children are finished");
    PASS(allPaused, "all children are paused");
    PASS([parent completedUnitCount] == 100, "parent is completed");
    [o release];
}

/* Resumes the parent of the observed progress when it gets paused */
@interface ResumingObserver : NSObject
{
    @public
    NSProgress *parent;
    BOOL resumed;
}
@end

@implementation ResumingObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    if (!resumed && [(NSProgress *)object isPaused]) {
        resumed = YES;
        [parent resume];
    }
}

@end

void checkResumingWhilePausing(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child1 = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *child2 = [NSProgress progressWithTotalUnitCount: 10];
    ResumingObserver *o = [[ResumingObserver alloc] init];

    o->parent = parent;
    [parent addChild: child1 withPendingUnitCount: 50];
    [parent addChild: child2 withPendingUnitCount: 50];
    [child1 addObserver: o forKeyPath: @"paused" options: 0 context: NULL];
    [child2 addObserver: o forKeyPath: @"paused" options: 0 context: NULL];
    /* macOS 26.6.2 deadlocks here like in checkChildFinishingWhilePausing(),
     * so this only tests GNUstep's behaviour.
     */
    [parent pause];
    PASS([parent isPaused] == NO, "parent is resumed by the observer");
    PASS([child1 isPaused] == NO && [child2 isPaused] == NO, "children follow the parent in order");
    [child1 removeObserver: o forKeyPath: @"paused"];
    [child2 removeObserver: o forKeyPath: @"paused"];
    [o release];
}

static volatile int threadsStarted = 0;
/* Counted once a thread's autorelease pool is drained, so that the test does
 * not exit while the thread still deallocates objects.
 */
static volatile int threadsDone = 0;

@interface Worker : NSObject
@end

@implementation Worker

/* Lets both threads start at the same time, so that they overlap */
- (void) waitForStart {
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 10.0];

    __sync_add_and_fetch(&threadsStarted, 1);
    while (threadsStarted < 2 && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0];
    }
}

- (void) pauseAndResume: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [progress pause];
        [progress resume];
    }
    [pool release];
    __sync_add_and_fetch(&threadsDone, 1);
}

- (void) updateCompletedUnitCount: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [progress setCompletedUnitCount: i % 100];
    }
    [pool release];
    __sync_add_and_fetch(&threadsDone, 1);
}

@end

void checkConcurrentPauseAndUpdate(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 1000];
    Worker *worker = [[Worker alloc] init];
    Observer *o = [[Observer alloc] init];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 30.0];

    [parent addChild: child withPendingUnitCount: 100];

    /* Pausing the parent pauses the child while the child updates the parent */
    [parent addObserver: o forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    [parent addObserver: o forKeyPath: @"paused" options: 0 context: NULL];
    [child addObserver: o forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    [child addObserver: o forKeyPath: @"paused" options: 0 context: NULL];
    [NSThread detachNewThreadSelector: @selector(pauseAndResume:)
                             toTarget: worker
                           withObject: parent];
    [NSThread detachNewThreadSelector: @selector(updateCompletedUnitCount:)
                             toTarget: worker
                           withObject: child];
    while (threadsDone < 2 && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0.01];
    }
    PASS(threadsDone == 2, "concurrent pausing and progress updates do not deadlock");
    if (threadsDone == 2) {
        [parent removeObserver: o forKeyPath: @"fractionCompleted"];
        [parent removeObserver: o forKeyPath: @"paused"];
        [child removeObserver: o forKeyPath: @"fractionCompleted"];
        [child removeObserver: o forKeyPath: @"paused"];
        [o release];
        [worker release];
    }
}

int main(void)
{
    ENTER_POOL

    checkPausable();
    checkHandlers();
    checkSettingHandlers();
    checkPropagationExplicitChildren();
    checkAddingChildren();
    checkStateInteraction();
    checkChildFinishingWhilePausing();
    checkResumingWhilePausing();
    checkConcurrentPauseAndUpdate();

    /* Deadlocked threads hold locks that exiting normally may wait for */
    if (threadsDone != 2) {
        fflush(stdout);
        fflush(stderr);
        _exit(0);
    }

    LEAVE_POOL
    return 0;
}
