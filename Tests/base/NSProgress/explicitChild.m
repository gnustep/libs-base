/* Test correct behaviour of explicitly adding children to an NSProgress instance */

#include "Foundation/NSException.h"
#include "GNUstepBase/GNUstep.h"
#import <Foundation/NSProgress.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

int main(void)
{
    ENTER_POOL

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

    /* child0 and child1 constitude 100% of the unit count of the parent */
    [parent addChild: child0 withPendingUnitCount: 50];
    [parent addChild: child1 withPendingUnitCount: 50];
    [child1 addChild: child2 withPendingUnitCount: 5];

    [child2 setCompletedUnitCount: 2];
    PASS([child2 fractionCompleted] == 2.0/5.0, "child2's fractionCompleted was updated");
    PASS([child1 fractionCompleted] == 2.0/10.0, "child1's fractionCompleted was updated");
    PASS([child2 isFinished] == NO, "child2 progress not finished yet");
    /* The pending unit count is only added after the progress finishes. However,
     * 'fractionCompleted' is always updated. */
    PASS([child1 completedUnitCount] == 0, "pending count was not added to child1");


    [child2 setCompletedUnitCount: 5];
    PASS([child2 fractionCompleted] == 1.0, "child2's fractionCompleted is 1.0");
    PASS([child1 fractionCompleted] == 5.0/10.0, "child1's fractionCompleted was updated (0.50)");
    PASS([parent fractionCompleted] == 25.0/100.0, "parent's fractionCompleted was updated");
    PASS([child2 isFinished], "child2's completedUnitCount equals its pendingUnitCount");
    PASS([child1 completedUnitCount] == 5, "pending count was added to child1");

    [child1 setCompletedUnitCount: 10];
    PASS([child1 fractionCompleted] == 10.0/10.0, "child1's fractionCompleted was updated");
    PASS([parent fractionCompleted] == 50.0/100.0, "parent's fractionCompleted was updated");
    PASS([child1 isFinished], "child1's completedUnitCount equals its pendingUnitCount");
    PASS([child1 completedUnitCount] == 10, "pending count was added to child1");

    [child0 setCompletedUnitCount: 10];
    PASS([child0 fractionCompleted] == 1.0, "child0's fractionCompleted was updated");
    PASS([parent fractionCompleted] == 1.0, "parent's fractionCompleted was updated ");
    PASS([child0 isFinished], "child0 is finished");
    PASS([parent isFinished], "parent is finished");


    LEAVE_POOL
    return 0;
}