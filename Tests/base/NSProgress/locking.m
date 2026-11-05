/* Test that observed progresses do not deadlock when used from several
 * threads.
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import "ObjectTesting.h"
#include <stdio.h>
#include <stdlib.h>

#if defined(_WIN32)
#include <process.h>
#else
#include <unistd.h>
#endif

@interface Observer : NSObject
@end

@implementation Observer

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
}

@end

/* Cancels the observed progress whenever its fraction changes */
@interface CancellingObserver : NSObject
@end

@implementation CancellingObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    [(NSProgress *)object cancel];
}

@end

/* Sets the throughput of the observed progress whenever it changes */
@interface ThroughputObserver : NSObject
@end

@implementation ThroughputObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    [(NSProgress *)object setThroughput: [NSNumber numberWithInt: 1]];
}

@end

/* Raises whenever the observed progress changes */
@interface RaisingObserver : NSObject
@end

@implementation RaisingObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    [NSException raise: @"ObserverException" format: @"raised by an observer"];
}

@end

/* Reads another progress whenever the observed one changes */
@interface ReadingObserver : NSObject
{
    @public
    NSProgress *other;
}
@end

@implementation ReadingObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    [other fractionCompleted];
}

@end

@interface Holder : NSObject
{
    NSProgress *progress;
}
@end

@implementation Holder

- (NSProgress *) progress {
    return progress;
}

- (void) setProgress: (NSProgress *)p {
    [p retain];
    [progress release];
    progress = p;
}

- (void) dealloc {
    [progress release];
    [super dealloc];
}

@end

/* Runs two loops on separate threads, which start at the same time so that
 * they overlap.
 */
@interface Worker : NSObject
{
    @public
    volatile int started;
    volatile int done;
}
@end

@implementation Worker

- (void) waitForStart {
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 10.0];

    __sync_add_and_fetch(&started, 1);
    while (started < 2 && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0];
    }
}

- (BOOL) waitUntilDone {
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow: 30.0];

    while (done < 2 && [limit timeIntervalSinceNow] > 0) {
        [NSThread sleepForTimeInterval: 0.01];
    }
    return done == 2;
}

- (void) updateCompletedUnitCount: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [progress setCompletedUnitCount: i % 100];
    }
    __sync_add_and_fetch(&done, 1);
    [pool release];
}

- (void) setProperties: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [progress setLocalizedAdditionalDescription: (i % 2) ? @"a" : @"b"];
        [progress setTotalUnitCount: 1000 + i % 2];
    }
    __sync_add_and_fetch(&done, 1);
    [pool release];
}

- (void) changeUserInfo: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [progress setUserInfoObject: (i % 2) ? @"a" : nil
                             forKey: [NSString stringWithFormat: @"key%d", i % 10]];
    }
    __sync_add_and_fetch(&done, 1);
    [pool release];
}

- (void) setFileTotalCount: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [progress setFileTotalCount: [NSNumber numberWithInt: i]];
    }
    __sync_add_and_fetch(&done, 1);
    [pool release];
}

- (void) copyUserInfo: (NSProgress *)progress {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        NSAutoreleasePool *inner = [NSAutoreleasePool new];
        NSDictionary *userInfo = [progress userInfo];
        id key;

        [[userInfo copy] release];
        [[userInfo mutableCopy] release];
        [userInfo description];
        [userInfo isEqual: [NSDictionary dictionary]];
        for (key in userInfo) {
            [userInfo objectForKey: key];
        }
        [inner release];
    }
    __sync_add_and_fetch(&done, 1);
    [pool release];
}

- (void) replaceProgress: (NSArray *)args {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    Holder *holder = [args objectAtIndex: 0];
    int i;

    [self waitForStart];
    for (i = 0; i < 20000; i++) {
        [holder setProgress: [args objectAtIndex: 1 + i % 2]];
    }
    __sync_add_and_fetch(&done, 1);
    [pool release];
}

@end

static BOOL deadlocked = NO;

/* Returns whether both loops finished.  On a deadlock, the worker and the
 * objects it uses are leaked.
 */
static BOOL runConcurrently(SEL first, id firstArg, SEL second, id secondArg)
{
    Worker *worker = [[Worker alloc] init];
    BOOL finished;

    [NSThread detachNewThreadSelector: first
                             toTarget: worker
                           withObject: firstArg];
    [NSThread detachNewThreadSelector: second
                             toTarget: worker
                           withObject: secondArg];
    finished = [worker waitUntilDone];
    if (finished) {
        [worker release];
    } else {
        deadlocked = YES;
    }
    return finished;
}

void checkConcurrentSettersAndUpdate(void) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 1000];
    Observer *o = [[Observer alloc] init];

    [progress addObserver: o forKeyPath: @"localizedAdditionalDescription" options: 0 context: NULL];
    [progress addObserver: o forKeyPath: @"totalUnitCount" options: 0 context: NULL];
    [progress addObserver: o forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    PASS(runConcurrently(@selector(setProperties:), progress,
                         @selector(updateCompletedUnitCount:), progress),
         "concurrent setters and progress updates do not deadlock");
    if (!deadlocked) {
        [progress removeObserver: o forKeyPath: @"localizedAdditionalDescription"];
        [progress removeObserver: o forKeyPath: @"totalUnitCount"];
        [progress removeObserver: o forKeyPath: @"fractionCompleted"];
        [o release];
    }
}

void checkObservingKeyPathWithValues(void) {
    NSProgress *progress1 = [NSProgress progressWithTotalUnitCount: 1000];
    NSProgress *progress2 = [NSProgress progressWithTotalUnitCount: 1000];
    Holder *holder = [[Holder alloc] init];
    Observer *o = [[Observer alloc] init];
    NSKeyValueObservingOptions options
      = NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew;

    /* KVO reads the old and new values of a key path while holding its own
     * locks, so replacing the progress reads it under these locks.
     */
    [holder setProgress: progress1];
    [holder addObserver: o forKeyPath: @"progress.localizedAdditionalDescription" options: options context: NULL];
    [holder addObserver: o forKeyPath: @"progress.fractionCompleted" options: options context: NULL];
    PASS(runConcurrently(@selector(replaceProgress:),
                         [NSArray arrayWithObjects: holder, progress1, progress2, nil],
                         @selector(setProperties:), progress1),
         "replacing an observed progress while setting its properties does not deadlock");
    if (!deadlocked) {
        [holder removeObserver: o forKeyPath: @"progress.localizedAdditionalDescription"];
        [holder removeObserver: o forKeyPath: @"progress.fractionCompleted"];
        [holder release];
        [o release];
    }
}

void checkCancellingFromObserver(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child1 = [NSProgress progressWithTotalUnitCount: 1000];
    NSProgress *child2 = [NSProgress progressWithTotalUnitCount: 1000];
    CancellingObserver *o = [[CancellingObserver alloc] init];

    [parent addChild: child1 withPendingUnitCount: 50];
    [parent addChild: child2 withPendingUnitCount: 50];

    /* The observer cancels the children of the parent while an update from
     * one child is being forwarded to it.
     */
    [parent addObserver: o forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    PASS(runConcurrently(@selector(updateCompletedUnitCount:), child1,
                         @selector(updateCompletedUnitCount:), child2),
         "cancelling from an observer while children update does not deadlock");
    if (!deadlocked) {
        PASS([child1 isCancelled] && [child2 isCancelled], "children are cancelled");
        [parent removeObserver: o forKeyPath: @"fractionCompleted"];
        [o release];
    }
}

void checkReadingFromObservers(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child1 = [NSProgress progressWithTotalUnitCount: 1000];
    NSProgress *child2 = [NSProgress progressWithTotalUnitCount: 1000];
    ReadingObserver *parentObserver = [[ReadingObserver alloc] init];
    ReadingObserver *childObserver = [[ReadingObserver alloc] init];

    [parent addChild: child1 withPendingUnitCount: 50];
    [parent addChild: child2 withPendingUnitCount: 50];

    /* Observers of the parent read a child and the other way round */
    parentObserver->other = child1;
    childObserver->other = parent;
    [parent addObserver: parentObserver forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    [child1 addObserver: childObserver forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    PASS(runConcurrently(@selector(updateCompletedUnitCount:), child1,
                         @selector(updateCompletedUnitCount:), child2),
         "observers reading other progresses do not deadlock");
    if (!deadlocked) {
        [parent removeObserver: parentObserver forKeyPath: @"fractionCompleted"];
        [child1 removeObserver: childObserver forKeyPath: @"fractionCompleted"];
        [parentObserver release];
        [childObserver release];
    }
}

void checkConcurrentUserInfo(void) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 10];

    PASS(runConcurrently(@selector(changeUserInfo:), progress,
                         @selector(copyUserInfo:), progress),
         "userInfo can be copied and enumerated while it changes");
}

void checkUserInfoAndUpdates(void) {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount: 1000];
    Observer *o = [[Observer alloc] init];
    ThroughputObserver *throughputObserver = [[ThroughputObserver alloc] init];

    /* localizedDescription depends on both completedUnitCount and userInfo */
    [progress addObserver: o forKeyPath: @"localizedDescription" options: 0 context: NULL];
    [progress addObserver: throughputObserver forKeyPath: @"completedUnitCount" options: 0 context: NULL];
    PASS(runConcurrently(@selector(updateCompletedUnitCount:), progress,
                         @selector(setFileTotalCount:), progress),
         "changing userInfo while observers of updates change it does not deadlock");
    if (!deadlocked) {
        [progress removeObserver: o forKeyPath: @"localizedDescription"];
        [progress removeObserver: throughputObserver forKeyPath: @"completedUnitCount"];
        [o release];
        [throughputObserver release];
    }
}

void checkRaisingObserver(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
    RaisingObserver *o = [[RaisingObserver alloc] init];

    [parent addChild: child withPendingUnitCount: 100];
    [child addObserver: o forKeyPath: @"completedUnitCount" options: 0 context: NULL];
    PASS_EXCEPTION([child setCompletedUnitCount: 10], @"ObserverException",
                   "exception of an observer is raised");
    [child removeObserver: o forKeyPath: @"completedUnitCount"];
    PASS([parent completedUnitCount] == 100, "parent is updated despite the exception");
    [child setCompletedUnitCount: 5];
    PASS([child completedUnitCount] == 5, "progress can still be changed after the exception");
    PASS(runConcurrently(@selector(updateCompletedUnitCount:), child,
                         @selector(updateCompletedUnitCount:), parent),
         "the exception left no lock held");

    NSProgress *cancelled = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *raising = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *other = [NSProgress progressWithTotalUnitCount: 10];
    [cancelled addChild: raising withPendingUnitCount: 50];
    [cancelled addChild: other withPendingUnitCount: 50];
    /* Both raise, so that one of them is cancelled after an exception */
    [raising addObserver: o forKeyPath: @"cancelled" options: 0 context: NULL];
    [other addObserver: o forKeyPath: @"cancelled" options: 0 context: NULL];
    PASS_EXCEPTION([cancelled cancel], @"ObserverException",
                   "exception of an observer of a child is raised");
    [raising removeObserver: o forKeyPath: @"cancelled"];
    [other removeObserver: o forKeyPath: @"cancelled"];
    PASS([raising isCancelled] && [other isCancelled], "other children are cancelled despite the exception");

    NSProgress *finishedChild = [NSProgress progressWithTotalUnitCount: 1];
    [finishedChild setCompletedUnitCount: 1];
    [finishedChild addObserver: o forKeyPath: @"cancelled" options: 0 context: NULL];
    PASS_EXCEPTION([cancelled addChild: finishedChild withPendingUnitCount: 10],
                   @"ObserverException",
                   "exception of an observer of an added child is raised");
    [finishedChild removeObserver: o forKeyPath: @"cancelled"];
    PASS([cancelled completedUnitCount] == 10, "added child's units are kept despite the exception");
    [o release];
}

int main(void)
{
    ENTER_POOL

    checkConcurrentSettersAndUpdate();
    if (!deadlocked) {
        checkObservingKeyPathWithValues();
    }
    if (!deadlocked) {
        checkCancellingFromObserver();
    }
    if (!deadlocked) {
        checkReadingFromObservers();
    }
    if (!deadlocked) {
        checkConcurrentUserInfo();
    }
    if (!deadlocked) {
        checkUserInfoAndUpdates();
    }
    if (!deadlocked) {
        checkRaisingObserver();
    }

    /* Deadlocked threads hold locks that exiting normally may wait for */
    if (deadlocked) {
        fflush(stdout);
        fflush(stderr);
        _exit(0);
    }

    LEAVE_POOL
    return 0;
}
