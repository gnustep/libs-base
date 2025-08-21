/* Test correct behaviour of setting the current progress and implicitly adding
 * children. */

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


    
    [parent release];

    LEAVE_POOL
    return 0;
}