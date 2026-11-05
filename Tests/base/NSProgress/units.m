/* Test how the units of children add up in their parent.
 * The expected behaviour was verified on macOS 26.6.2 (25G83).
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSException.h>
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

void checkPastTotal(void) {
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    Observer *o = [[Observer alloc] init];

    [p addObserver: o forKeyPath: @"finished" options: 0 context: NULL];
    [p setCompletedUnitCount: 20];
    PASS([p isFinished], "progress past its total is finished");
    PASS([p fractionCompleted] == 2.0, "fractionCompleted past the total is above 1.0");
    [p setTotalUnitCount: 40];
    PASS([p isFinished] == NO, "raising the total unfinishes the progress");
    PASS([p fractionCompleted] == 0.5, "fractionCompleted follows the total");
    [p setCompletedUnitCount: 40];
    PASS([p isFinished], "progress finishes again");
    PASS(o->observations == 3, "received KVO notifications for each change of finished");
    [p removeObserver: o forKeyPath: @"finished"];
    [o release];
}

void checkRefinishingChild(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];

    [parent addChild: child withPendingUnitCount: 50];
    [child setCompletedUnitCount: 10];
    PASS([parent completedUnitCount] == 50, "finished child adds its pending unit count");
    PASS([parent fractionCompleted] == 0.5, "parent's fractionCompleted includes the child");

    [child setTotalUnitCount: 40];
    PASS([child isFinished] == NO, "child is unfinished by raising its total");
    PASS([parent completedUnitCount] == 50, "parent keeps the pending unit count");
    PASS([parent fractionCompleted] == 0.125, "parent's fractionCompleted follows the child");
    [child setCompletedUnitCount: 20];
    PASS([parent fractionCompleted] == 0.25, "unfinished child still updates its parent");

    [parent pause];
    PASS([child isPaused] == NO, "child that finished before is not paused with its parent");

    [child setCompletedUnitCount: 40];
    PASS([parent completedUnitCount] == 100, "child adds its pending unit count whenever it finishes");
    PASS([parent fractionCompleted] == 0.5, "added unit counts are not counted twice in fractionCompleted");
}

void checkPartlyCompletedChild(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];

    [child setCompletedUnitCount: 5];
    [parent addChild: child withPendingUnitCount: 50];
    PASS([parent fractionCompleted] == 0.25, "partly completed child counts when it is added");
    [child setCompletedUnitCount: 10];
    PASS([parent completedUnitCount] == 50, "child adds its pending unit count");
    PASS([parent fractionCompleted] == 0.5, "parent's fractionCompleted includes the child");
}

void checkIndeterminateChild(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *other = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: -1];

    [parent addChild: other withPendingUnitCount: 50];
    [parent addChild: child withPendingUnitCount: 50];
    [other setCompletedUnitCount: 5];
    [child setCompletedUnitCount: 5];
    PASS([child fractionCompleted] == 0.0, "indeterminate child has no fractionCompleted");
    PASS([parent fractionCompleted] == 0.25, "indeterminate child does not change its parent");
    [child setTotalUnitCount: 10];
    PASS([child fractionCompleted] == 0.5, "fractionCompleted follows a new total");
    PASS([parent fractionCompleted] == 0.5, "determinate child updates its parent");
    [child setTotalUnitCount: -1];
    PASS([parent fractionCompleted] == 0.25, "child becoming indeterminate updates its parent");
}

void checkParentWithoutTotal(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 0];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];

    /* The progress of children is lost while the parent has no total */
    [parent addChild: child withPendingUnitCount: 50];
    [child setCompletedUnitCount: 5];
    PASS([parent fractionCompleted] == 0.0, "parent without total has no fractionCompleted");
    [parent setTotalUnitCount: 100];
    PASS([parent fractionCompleted] == 0.0, "progress of the child is lost");
    [child setCompletedUnitCount: 10];
    PASS([parent completedUnitCount] == 50, "child adds its pending unit count");
    PASS([parent fractionCompleted] == 0.25, "later progress of the child counts");
}

void checkAddingChildTwice(void) {
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *other = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];

    [parent addChild: child withPendingUnitCount: 50];
    PASS_EXCEPTION([other addChild: child withPendingUnitCount: 50],
                   NSInvalidArgumentException,
                   "adding a child to a second parent raises");
    [child setCompletedUnitCount: 10];
    PASS([parent completedUnitCount] == 50, "child still belongs to its first parent");
    PASS([other completedUnitCount] == 0, "child does not belong to the second parent");
}

int main(void)
{
    ENTER_POOL

    checkPastTotal();
    checkRefinishingChild();
    checkPartlyCompletedChild();
    checkIndeterminateChild();
    checkParentWithoutTotal();
    checkAddingChildTwice();

    LEAVE_POOL
    return 0;
}
