/* Test correct behaviour of setting the current progress and implicitly adding
 * children. */

/* These test the block-based API */
#define GS_SUPPRESS_NON_PORTABLE_CODE_WARNINGS 1

#include "Foundation/NSException.h"
#include "GNUstepBase/GNUstep.h"
#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

/*
 * Rules for the current progress and implicit children
 * 1. +[NSProgress currentProgress] == nil if no progress assumes the role of becoming a current progress
 * 2. -[NSProgress becomeCurrentWithPendingUnitCount:] makes the receiver the
 * new current progress. The old currentProgress is stored in a LIFO manner.
 * 3. Only the first progress object instantiated after -[NSProgress
 * becomeCurrent..] is invoked is implicitly added as a child to the current
 * progress.
 */

int main(void)
{
    ENTER_POOL

    NSProgress *parent =  [[NSProgress alloc] initWithParent: nil userInfo: nil];
    [parent setTotalUnitCount: 10];

    PASS_EXCEPTION([[NSProgress alloc] initWithParent: parent userInfo: nil], NSInvalidArgumentException, "The only valid values are currentProgress or nil");

    [parent becomeCurrentWithPendingUnitCount: 10];
    PASS_EQUAL([NSProgress currentProgress], parent, "parent is now the currentProgress");

    /* The first progress object instantiated after a progress becomes current is
     * always the implicit child of the current progress.
     * We test if this holds by incrementing the completedUnitCount of child. */
    NSProgress *child = [NSProgress progressWithTotalUnitCount: 10];
    [child setCompletedUnitCount: 5];

    /* Only after the condition (completedUnitCount == totalUnitCount) holds for
     * the child, the pendingUnitCount is added to parent's completedUnitCount. */
    PASS([parent completedUnitCount] == 0, "the child progress has not completed all of the work yet");
    PASS([child isFinished] == NO, "child progress is not finished");

    /* We will now instantiate a new progress object "progress1". We will verify
     * that this progress object is not an implicit child of parent by setting
     * (completedUnitCount == totalUnitCount). The parent's unit count only
     * increases if "parent1" is indeed an implicit child that completed all of
     * the work before "child". */
    NSProgress *progress1 = [NSProgress progressWithTotalUnitCount: 20];
    [progress1 setCompletedUnitCount: 20];
    PASS([progress1 isFinished], "progress1 finished all of its work");
    /* Check that progress1 did not influence parent */
    PASS([parent completedUnitCount] == 0, "progress1 is not an implicit child of parent");

    [child setCompletedUnitCount: 10];
    PASS([child isFinished], "child progress is finished");
    PASS([parent completedUnitCount] == 10, "the pending unit count has been added to the parent");

    /* Create a new progress that will assume the role of a currentProgress.
     * We expect parent to become current again, after the new progress resigns the role. */
    NSProgress * parent1 = [[NSProgress alloc] initWithParent: nil userInfo: nil];
    [parent1 becomeCurrentWithPendingUnitCount: 10];
    PASS_EQUAL([NSProgress currentProgress], parent1, "currentProgress is parent1");

    [parent1 resignCurrent];
    PASS_EQUAL([NSProgress currentProgress], parent, "currentProgress is parent");

    /* currentProgress is set to parent until another progress becomes current,
     * or parent resigns being a currentProgress */
    [parent resignCurrent];
    PASS_EQUAL([NSProgress currentProgress], nil, "currentProgress should now be nil");


    
    /* Like on macOS, the pending unit count is completed if no child used it */
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 100];
    [p becomeCurrentWithPendingUnitCount: 30];
    [p resignCurrent];
    PASS([p completedUnitCount] == 30, "resignCurrent without a child completes the pending unit count");
    [p becomeCurrentWithPendingUnitCount: 20];
    NSProgress *implicitChild = [NSProgress progressWithTotalUnitCount: 10];
    [p resignCurrent];
    PASS([p completedUnitCount] == 30, "resignCurrent with a child does not complete the pending unit count");
    [implicitChild setCompletedUnitCount: 10];
    PASS([p completedUnitCount] == 50, "the implicit child adds the pending unit count");

    /* An explicit child neither needs a current parent nor takes the pending
     * unit count of a current parent.
     */
    NSProgress *explicitParent = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress *explicitChild = [NSProgress progressWithTotalUnitCount: 10 parent: explicitParent pendingUnitCount: 50];
    [explicitChild setCompletedUnitCount: 10];
    PASS([explicitParent completedUnitCount] == 50, "explicit child of a parent that is not current");
    [explicitParent becomeCurrentWithPendingUnitCount: 30];
    explicitChild = [NSProgress progressWithTotalUnitCount: 10 parent: explicitParent pendingUnitCount: 20];
    implicitChild = [NSProgress progressWithTotalUnitCount: 10];
    [explicitParent resignCurrent];
    [explicitChild setCompletedUnitCount: 10];
    PASS([explicitParent completedUnitCount] == 70, "explicit child of a current parent");
    [implicitChild setCompletedUnitCount: 10];
    PASS([explicitParent completedUnitCount] == 100, "implicit child takes the pending unit count");

    /* Like on macOS, only a progress created with the current progress as its
     * parent becomes an implicit child.
     */
    NSProgress *current = [NSProgress progressWithTotalUnitCount: 100];
    [current becomeCurrentWithPendingUnitCount: 10];
    [[[NSProgress alloc] initWithParent: nil userInfo: nil] release];
    [[[NSProgress alloc] init] release];
    [NSProgress discreteProgressWithTotalUnitCount: 10];
    [current resignCurrent];
    PASS([current completedUnitCount] == 10, "progress created with a nil parent, -init or as discrete is not an implicit child");
    [current becomeCurrentWithPendingUnitCount: 20];
    [[[NSProgress alloc] initWithParent: nil userInfo: nil] release];
    implicitChild = [[[NSProgress alloc] initWithParent: [NSProgress currentProgress] userInfo: nil] autorelease];
    [current resignCurrent];
    PASS([current completedUnitCount] == 10, "progress created with the current progress as its parent is an implicit child");
    [implicitChild setTotalUnitCount: 1];
    [implicitChild setCompletedUnitCount: 1];
    PASS([current completedUnitCount] == 30, "the implicit child adds the pending unit count");

#if __has_feature(blocks)
    NSProgress *performing = [NSProgress progressWithTotalUnitCount: 100];
    NSProgress * __block currentInBlock = nil;
    NSProgress * __block childInBlock = nil;
    [performing performAsCurrentWithPendingUnitCount: 40 usingBlock: ^{
        currentInBlock = [NSProgress currentProgress];
    }];
    PASS(currentInBlock == performing, "receiver is current while performing the block");
    PASS([NSProgress currentProgress] == nil, "receiver is no longer current after the block");
    PASS([performing completedUnitCount] == 40, "pending unit count is completed without a child");
    [performing performAsCurrentWithPendingUnitCount: 20 usingBlock: ^{
        childInBlock = [NSProgress progressWithTotalUnitCount: 10];
    }];
    PASS([performing completedUnitCount] == 40, "pending unit count is not completed with a child");
    [childInBlock setCompletedUnitCount: 10];
    PASS([performing completedUnitCount] == 60, "child created in the block adds the pending unit count");
#endif

    /* Like on macOS, only the current progress can resign */
    NSProgress *other = [NSProgress progressWithTotalUnitCount: 10];
    PASS_EXCEPTION([other resignCurrent], NSInvalidArgumentException, "resigning a progress that is not current raises");
    [other becomeCurrentWithPendingUnitCount: 5];
    [p becomeCurrentWithPendingUnitCount: 5];
    PASS_EXCEPTION([other resignCurrent], NSInvalidArgumentException, "resigning a progress that is not the top one raises");
    [p resignCurrent];
    [other resignCurrent];
    PASS_EQUAL([NSProgress currentProgress], nil, "currentProgress is nil again");

    RELEASE(parent);
    RELEASE(parent1);

    LEAVE_POOL
    return 0;
}
