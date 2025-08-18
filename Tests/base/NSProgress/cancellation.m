/* Test propragation of progress cancellation to children */

#include "Foundation/NSException.h"
#include "GNUstepBase/GNUstep.h"
#import <Foundation/NSProgress.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

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
}

int main(void)
{
    ENTER_POOL

    checkPropagationExplicitChildren();

    LEAVE_POOL
    return 0;
}