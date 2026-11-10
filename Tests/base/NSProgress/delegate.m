/* Test the delegate of NSProgress, the portable alternative to its
 * cancellation, pausing and resuming handlers.
 */

/* Replacing the handlers is part of what is tested */
#define GS_SUPPRESS_NON_PORTABLE_CODE_WARNINGS 1

#import <Foundation/NSObject.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSAutoreleasePool.h>
#import <GNUstepBase/NSProgress+GNUstepBase.h>
#import "ObjectTesting.h"

@interface Delegate : NSObject <GSProgressDelegate>
{
    @public
    volatile int cancelled;
    volatile int paused;
    volatile int resumed;
    NSProgress *lastProgress;
    NSThread *lastThread;
}
@end

@implementation Delegate

- (void) record: (NSProgress *)progress {
    lastProgress = progress;
    lastThread = [NSThread currentThread];
}

- (void) progressCancelled: (NSProgress *)progress {
    [self record: progress];
    __sync_add_and_fetch(&cancelled, 1);
}

- (void) progressPaused: (NSProgress *)progress {
    [self record: progress];
    __sync_add_and_fetch(&paused, 1);
}

- (void) progressResumed: (NSProgress *)progress {
    [self record: progress];
    __sync_add_and_fetch(&resumed, 1);
}

@end

/* The delegate may be sent messages asynchronously.  Waits until the counter
 * reaches the expected value, then a bit longer to catch unexpected calls.
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

void checkMessages(void) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 10];
    Delegate *d = [[Delegate alloc] init];

    [progress setDelegate: d];
    PASS([progress delegate] == d, "delegate getter returns the delegate");

    [progress resume];
    PASS(waitForCount(&d->resumed, 1), "delegate is told about resuming when not paused");
    [progress pause];
    PASS(waitForCount(&d->paused, 1), "delegate is told about pausing");
    PASS(d->lastProgress == progress, "delegate is passed the progress");
    PASS(d->lastThread != [NSThread currentThread],
      "delegate is sent messages asynchronously")
    [progress pause];
    PASS(waitForCount(&d->paused, 2), "delegate is told about pausing again");
    [progress resume];
    PASS(waitForCount(&d->resumed, 2), "delegate is told about resuming");
    [progress cancel];
    PASS(waitForCount(&d->cancelled, 1), "delegate is told about cancelling");

    [progress setDelegate: nil];
    PASS([progress delegate] == nil, "delegate can be removed");
    [progress pause];
    PASS(waitForCount(&d->paused, 2), "removed delegate is not told about pausing");
    [d release];
}

void checkSettingDelegate(void) {
    NSProgress *paused = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *cancelled = [NSProgress progressWithTotalUnitCount: 10];
    Delegate *d = [[Delegate alloc] init];

    [paused pause];
    [paused setDelegate: d];
    PASS(waitForCount(&d->paused, 1), "delegate set on a paused progress is told about pausing");
    PASS(d->resumed == 0 && d->cancelled == 0, "delegate is told nothing else");

    [cancelled cancel];
    [cancelled setDelegate: d];
    PASS(waitForCount(&d->cancelled, 1), "delegate set on a cancelled progress is told about cancelling");
    [d release];
}

void checkChildren(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
    Delegate *d = [[Delegate alloc] init];

    [parent addChild: child withPendingUnitCount: 50];
    [child setDelegate: d];
    [parent pause];
    PASS(waitForCount(&d->paused, 1), "delegate of a child is told about pausing with the parent");
    PASS(d->lastProgress == child, "delegate is passed the child");
    [parent resume];
    PASS(waitForCount(&d->resumed, 1), "delegate of a child is told about resuming with the parent");
    [parent cancel];
    PASS(waitForCount(&d->cancelled, 1), "delegate of a child is told about cancelling with the parent");
    [d release];
}

void checkWeakDelegate(void) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 10];
    Delegate *d = [[Delegate alloc] init];

    [progress setDelegate: d];
    [d release];
    PASS([progress delegate] == nil, "progress does not retain the delegate");
    [progress pause];
    [progress resume];
    [progress cancel];
    [NSThread sleepForTimeInterval: 0.1];
    PASS([progress isCancelled], "progress works without its released delegate");
}

void checkReplacingHandlers(void) {
#if __has_feature(blocks)
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 10];
    Delegate *d = [[Delegate alloc] init];
    volatile int __block handlerCalls = 0;

    [progress setPausingHandler: ^(void){
        __sync_add_and_fetch(&handlerCalls, 1);
    }];
    [progress setDelegate: d];
    [progress pause];
    PASS(waitForCount(&d->paused, 1), "delegate is told about pausing");
    PASS(handlerCalls == 0, "delegate replaces the pausing handler");
    [d release];
#endif
}

int main(void)
{
    ENTER_POOL

    checkMessages();
    checkSettingDelegate();
    checkChildren();
    checkWeakDelegate();
    checkReplacingHandlers();

    LEAVE_POOL
    return 0;
}
